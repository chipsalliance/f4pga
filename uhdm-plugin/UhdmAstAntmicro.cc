#define mkconst_real(x) AST::AstNode::mkconst_real(x)

void UhdmAst::visit_range(vpiHandle obj_h, const std::function<void(AST::AstNode *)> &f)
{
    std::vector<AST::AstNode *> range_nodes;
    visit_one_to_many({vpiRange}, obj_h, [&](AST::AstNode *node) { range_nodes.push_back(node); });
    if (range_nodes.size() > 1) {
        auto multirange_node = new AST::AstNode(AST::AST_MULTIRANGE);
        multirange_node->is_packed = true;
        multirange_node->children = range_nodes;
        f(multirange_node);
    } else if (!range_nodes.empty()) {
        f(range_nodes[0]);
    }
}

void UhdmAst::process_parameter()
{
    auto type = vpi_get(vpiLocalParam, obj_h) == 1 ? AST::AST_LOCALPARAM : AST::AST_PARAMETER;
    current_node = make_ast_node(type, {}, true);
    // if (vpi_get_str(vpiImported, obj_h) != "") { } //currently unused
    std::vector<AST::AstNode *> range_nodes;
    visit_range(obj_h, [&](AST::AstNode *node) {
        if (node)
            range_nodes.push_back(node);
    });
    vpiHandle typespec_h = vpi_handle(vpiTypespec, obj_h);
    if (typespec_h) {
        int typespec_type = vpi_get(vpiType, typespec_h);
        switch (typespec_type) {
        case vpiBitTypespec:
        case vpiLogicTypespec: {
            current_node->is_logic = true;
            visit_range(typespec_h, [&](AST::AstNode *node) { range_nodes.push_back(node); });
            shared.report.mark_handled(typespec_h);
            break;
        }
        case vpiEnumTypespec:
        case vpiRealTypespec:
        case vpiIntTypespec: {
            shared.report.mark_handled(typespec_h);
            break;
        }
        case vpiStructTypespec: {
            visit_one_to_one({vpiTypespec}, obj_h, [&](AST::AstNode *node) {
                auto wiretype_node = make_ast_node(AST::AST_WIRETYPE);
                wiretype_node->str = node->str;
                current_node->children.push_back(wiretype_node);
                current_node->is_custom_type = true;
                auto it = shared.param_types.find(current_node->str);
                if (it == shared.param_types.end())
                    shared.param_types.insert(std::make_pair(current_node->str, node));
            });
            break;
        }
        case vpiArrayTypespec: {
            shared.report.mark_handled(typespec_h);
            visit_one_to_one({vpiElemTypespec}, typespec_h, [&](AST::AstNode *node) {
                if (node) {
                    range_nodes.push_back(node->children[0]);
                }
            });

            break;
        }
        default: {
            const uhdm_handle *const handle = (const uhdm_handle *)typespec_h;
            const UHDM::BaseClass *const object = (const UHDM::BaseClass *)handle->object;
            report_error("%s:%d: Encountered unhandled typespec in process_parameter: '%s' of type '%s'\n", object->VpiFile().c_str(),
                         object->VpiLineNo(), object->VpiName().c_str(), UHDM::VpiTypeName(typespec_h).c_str());
            break;
        }
        }
        vpi_release_handle(typespec_h);
    } else {
        AST::AstNode *constant_node = process_value(obj_h);
        if (constant_node) {
            constant_node->filename = current_node->filename;
            constant_node->location = current_node->location;
            current_node->children.push_back(constant_node);
        }
    }
    if (range_nodes.size() > 1) {
        auto multirange_node = new AST::AstNode(AST::AST_MULTIRANGE);
        multirange_node->is_packed = true;
        multirange_node->children = range_nodes;
        current_node->children.push_back(multirange_node);
    } else if (range_nodes.size() == 1) {
        current_node->children.push_back(range_nodes[0]);
    }
}

void UhdmAst::process_port()
{
    current_node = make_ast_node(AST::AST_WIRE);
    current_node->port_id = shared.next_port_id();
    vpiHandle lowConn_h = vpi_handle(vpiLowConn, obj_h);
    if (lowConn_h) {
        vpiHandle actual_h = vpi_handle(vpiActual, lowConn_h);
        auto actual_type = vpi_get(vpiType, actual_h);
        switch (actual_type) {
        case vpiModport: {
            vpiHandle iface_h = vpi_handle(vpiInterface, actual_h);
            if (iface_h) {
                std::string cellName, ifaceName;
                if (auto s = vpi_get_str(vpiName, actual_h)) {
                    cellName = s;
                    sanitize_symbol_name(cellName);
                }
                if (auto s = vpi_get_str(vpiDefName, iface_h)) {
                    ifaceName = s;
                    sanitize_symbol_name(ifaceName);
                }
                current_node->type = AST::AST_INTERFACEPORT;
                auto typeNode = new AST::AstNode(AST::AST_INTERFACEPORTTYPE);
                // Skip '\' in cellName
                typeNode->str = ifaceName + '.' + cellName.substr(1, cellName.length());
                current_node->children.push_back(typeNode);
                shared.report.mark_handled(actual_h);
                shared.report.mark_handled(iface_h);
                vpi_release_handle(iface_h);
            }
            break;
        }
        case vpiInterface: {
            auto typeNode = new AST::AstNode(AST::AST_INTERFACEPORTTYPE);
            if (auto s = vpi_get_str(vpiDefName, actual_h)) {
                typeNode->str = s;
                sanitize_symbol_name(typeNode->str);
            }
            current_node->type = AST::AST_INTERFACEPORT;
            current_node->children.push_back(typeNode);
            shared.report.mark_handled(actual_h);
            break;
        }
        case vpiLogicVar:
        case vpiLogicNet: {
            current_node->is_logic = true;
            current_node->is_signed = vpi_get(vpiSigned, actual_h);
            visit_range(actual_h, [&](AST::AstNode *node) {
                if (node->type == AST::AST_MULTIRANGE)
                    node->is_packed = true;
                current_node->children.push_back(node);
            });
            shared.report.mark_handled(actual_h);
            break;
        }
        case vpiPackedArrayVar:
            visit_one_to_many({vpiElement}, actual_h, [&](AST::AstNode *node) {
                if (node && GetSize(node->children) == 1) {
                    current_node->children.push_back(node->children[0]);
                    if (node->children[0]->type == AST::AST_WIRETYPE) {
                        current_node->is_custom_type = true;
                    }
                }
            });
            visit_one_to_many({vpiRange}, actual_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
            shared.report.mark_handled(actual_h);
            break;
        case vpiPackedArrayNet:
            visit_one_to_many({vpiRange}, actual_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
            shared.report.mark_handled(actual_h);
            break;
        case vpiArrayVar:
            visit_one_to_many({vpiRange}, actual_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
            shared.report.mark_handled(actual_h);
            break;
        case vpiEnumNet:
        case vpiStructNet:
        case vpiArrayNet:
        case vpiStructVar:
        case vpiEnumVar:
        case vpiShortIntVar:
        case vpiIntVar:
            break;
        default: {
            const uhdm_handle *const handle = (const uhdm_handle *)actual_h;
            const UHDM::BaseClass *const object = (const UHDM::BaseClass *)handle->object;
            report_error("%s:%d: Encountered unhandled type in process_port: %s\n", object->VpiFile().c_str(), object->VpiLineNo(),
                         UHDM::VpiTypeName(actual_h).c_str());
            break;
        }
        }
        shared.report.mark_handled(lowConn_h);
        vpi_release_handle(actual_h);
        vpi_release_handle(lowConn_h);
    }
    visit_one_to_one({vpiTypedef}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            if (!current_node->children.empty() && current_node->children[0]->type != AST::AST_WIRETYPE) {
                if (!node->str.empty()) {
                    auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
                    wiretype_node->str = node->str;
                    // wiretype needs to be 1st node (if port have also another range nodes)
                    current_node->children.insert(current_node->children.begin(), wiretype_node);
                    current_node->is_custom_type = true;
                } else {
                    // anonymous typedef, just move children
                    current_node->children = std::move(node->children);
                }
            }
            delete node;
        }
    });
    if (const int n = vpi_get(vpiDirection, obj_h)) {
        if (n == vpiInput) {
            current_node->is_input = true;
        } else if (n == vpiOutput) {
            current_node->is_output = true;
        } else if (n == vpiInout) {
            current_node->is_input = true;
            current_node->is_output = true;
        }
    }
}

void UhdmAst::process_net()
{
    current_node = make_ast_node(AST::AST_WIRE);
    auto net_type = vpi_get(vpiNetType, obj_h);
    current_node->is_reg = net_type == vpiReg;
    current_node->is_output = net_type == vpiOutput;
    current_node->is_logic = !current_node->is_reg;
    current_node->is_signed = vpi_get(vpiSigned, obj_h);
    visit_one_to_one({vpiTypespec}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
            wiretype_node->str = node->str;
            // wiretype needs to be 1st node
            current_node->children.insert(current_node->children.begin(), wiretype_node);
            current_node->is_custom_type = true;
        }
    });
    visit_range(obj_h, [&](AST::AstNode *node) {
        current_node->children.push_back(node);
        if (node->type == AST::AST_MULTIRANGE) {
            node->is_packed = true;
        }
    });
}

void UhdmAst::process_tagged_pattern()
{
    auto assign_node = find_ancestor({AST::AST_ASSIGN, AST::AST_ASSIGN_EQ, AST::AST_ASSIGN_LE});
    auto assign_type = AST::AST_ASSIGN;
    AST::AstNode *lhs_node = nullptr;
    if (assign_node) {
        assign_type = assign_node->type;
        lhs_node = assign_node->children[0];
    } else {
        lhs_node = new AST::AstNode(AST::AST_IDENTIFIER);
        lhs_node->str = find_ancestor({AST::AST_WIRE, AST::AST_MEMORY, AST::AST_PARAMETER, AST::AST_LOCALPARAM})->str;
    }
    current_node = new AST::AstNode(assign_type);
    current_node->children.push_back(lhs_node->clone());
    auto typespec_h = vpi_handle(vpiTypespec, obj_h);
    if (vpi_get(vpiType, typespec_h) == vpiStringTypespec) {
        std::string field_name = vpi_get_str(vpiName, typespec_h);
        if (field_name != "default") { // TODO: better support of the default keyword
            auto field = new AST::AstNode(AST::AST_DOT);
            field->str = field_name;
            current_node->children[0]->children.push_back(field);
        }
    } else if (vpi_get(vpiType, typespec_h) == vpiIntegerTypespec) {
        s_vpi_value val;
        vpi_get_value(typespec_h, &val);
        auto range = new AST::AstNode(AST::AST_RANGE);
        auto index = AST::AstNode::mkconst_int(val.value.integer, false);
        range->children.push_back(index);
        current_node->children[0]->children.push_back(range);
    }
    vpi_release_handle(typespec_h);
    visit_one_to_one({vpiPattern}, obj_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
}

void UhdmAst::process_var_select()
{
    current_node = make_ast_node(AST::AST_IDENTIFIER);
    visit_one_to_many({vpiIndex}, obj_h, [&](AST::AstNode *node) {
        if (node->str == current_node->str) {
            for (auto child : node->children) {
                current_node->children.push_back(child);
            }
            node->children.clear();
            delete node;
        } else {
            auto range_node = new AST::AstNode(AST::AST_RANGE);
            range_node->filename = current_node->filename;
            range_node->location = current_node->location;
            range_node->children.push_back(node);
            current_node->children.push_back(range_node);
        }
    });
    if (current_node->children.size() > 1) {
        auto multirange_node = new AST::AstNode(AST::AST_MULTIRANGE);
        multirange_node->is_packed = true;
        multirange_node->children = current_node->children;
        current_node->children.clear();
        current_node->children.push_back(multirange_node);
    }
}

void UhdmAst::process_gen_scope_array()
{
    current_node = make_ast_node(AST::AST_GENBLOCK);
    visit_one_to_many({vpiGenScope}, obj_h, [&](AST::AstNode *genscope_node) {
        for (auto *child : genscope_node->children) {
            if (child->type == AST::AST_PARAMETER || child->type == AST::AST_LOCALPARAM) {
                auto param_str = child->str.substr(1);
                auto array_str = "[" + param_str + "]";
                genscope_node->visitEachDescendant([&](AST::AstNode *node) {
                    auto pos = node->str.find(array_str);
                    if (pos != std::string::npos) {
                        node->type = AST::AST_PREFIX;
                        auto *param = new AST::AstNode(AST::AST_IDENTIFIER);
                        param->str = child->str;
                        node->children.push_back(param);
                        auto bracket = node->str.rfind(']');
                        if (bracket + 2 <= node->str.size()) {
                            auto *field = new AST::AstNode(AST::AST_IDENTIFIER);
                            field->str = "\\" + node->str.substr(bracket + 2);
                            node->children.push_back(field);
                        }
                        node->str = node->str.substr(0, node->str.find('['));
                    }
                });
            }
        }
        current_node->children.insert(current_node->children.end(), genscope_node->children.begin(), genscope_node->children.end());
        genscope_node->children.clear();
        delete genscope_node;
    });
}

void UhdmAst::process_hier_path()
{
    current_node = make_ast_node(AST::AST_IDENTIFIER);
    current_node->str = "\\";
    AST::AstNode *top_node = nullptr;
    visit_one_to_many({vpiActual}, obj_h, [&](AST::AstNode *node) {
        if (node->str.find('[') != std::string::npos)
            node->str = node->str.substr(0, node->str.find('['));
        // for first node, just set correct string and move any children
        if (!top_node) {
            current_node->str += node->str.substr(1);
            current_node->children = std::move(node->children);
            top_node = current_node;
            delete node;
        } else { // for other nodes, change type to AST_DOT
            node->type = AST::AST_DOT;
            top_node->children.push_back(node);
            top_node = node;
        }
    });
}
