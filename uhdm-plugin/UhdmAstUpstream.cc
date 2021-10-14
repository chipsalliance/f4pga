namespace RTLIL
{
namespace ID
{
IdString partial;
}
} // namespace RTLIL

static AST::AstNode *mkconst_real(double d)
{
    AST::AstNode *node = new AST::AstNode(AST::AST_REALVALUE);
    node->realvalue = d;
    return node;
}
namespace VERILOG_FRONTEND
{
using namespace AST;
// divide an arbitrary length decimal number by two and return the rest
static int my_decimal_div_by_two(std::vector<uint8_t> &digits)
{
    int carry = 0;
    for (size_t i = 0; i < digits.size(); i++) {
        if (digits[i] >= 10)
            log_file_error(current_filename, get_line_num(), "Invalid use of [a-fxz?] in decimal constant.\n");
        digits[i] += carry * 10;
        carry = digits[i] % 2;
        digits[i] /= 2;
    }
    while (!digits.empty() && !digits.front())
        digits.erase(digits.begin());
    return carry;
}

// find the number of significant bits in a binary number (not including the sign bit)
static int my_ilog2(int x)
{
    int ret = 0;
    while (x != 0 && x != -1) {
        x = x >> 1;
        ret++;
    }
    return ret;
}

// parse a binary, decimal, hexadecimal or octal number with support for special bits ('x', 'z' and '?')
static void my_strtobin(std::vector<RTLIL::State> &data, const char *str, int len_in_bits, int base, char case_type, bool is_unsized)
{
    // all digits in string (MSB at index 0)
    std::vector<uint8_t> digits;

    while (*str) {
        if ('0' <= *str && *str <= '9')
            digits.push_back(*str - '0');
        else if ('a' <= *str && *str <= 'f')
            digits.push_back(10 + *str - 'a');
        else if ('A' <= *str && *str <= 'F')
            digits.push_back(10 + *str - 'A');
        else if (*str == 'x' || *str == 'X')
            digits.push_back(0xf0);
        else if (*str == 'z' || *str == 'Z' || *str == '?')
            digits.push_back(0xf1);
        str++;
    }

    if (base == 10 && GetSize(digits) == 1 && digits.front() >= 0xf0)
        base = 2;

    data.clear();

    if (base == 10) {
        while (!digits.empty())
            data.push_back(my_decimal_div_by_two(digits) ? State::S1 : State::S0);
    } else {
        int bits_per_digit = my_ilog2(base - 1);
        for (auto it = digits.rbegin(), e = digits.rend(); it != e; it++) {
            if (*it > (base - 1) && *it < 0xf0)
                log_file_error(current_filename, get_line_num(), "Digit larger than %d used in in base-%d constant.\n", base - 1, base);
            for (int i = 0; i < bits_per_digit; i++) {
                int bitmask = 1 << i;
                if (*it == 0xf0)
                    data.push_back(case_type == 'x' ? RTLIL::Sa : RTLIL::Sx);
                else if (*it == 0xf1)
                    data.push_back(case_type == 'x' || case_type == 'z' ? RTLIL::Sa : RTLIL::Sz);
                else
                    data.push_back((*it & bitmask) ? State::S1 : State::S0);
            }
        }
    }

    int len = GetSize(data);
    RTLIL::State msb = data.empty() ? State::S0 : data.back();

    if (len_in_bits < 0) {
        if (len < 32)
            data.resize(32, msb == State::S0 || msb == State::S1 ? RTLIL::S0 : msb);
        return;
    }

    if (is_unsized && (len > len_in_bits))
        log_file_error(current_filename, get_line_num(), "Unsized constant must have width of 1 bit, but have %d bits!\n", len);

    for (len = len - 1; len >= 0; len--)
        if (data[len] == State::S1)
            break;
    if (msb == State::S0 || msb == State::S1) {
        len += 1;
        data.resize(len_in_bits, State::S0);
    } else {
        len += 2;
        data.resize(len_in_bits, msb);
    }

    if (len_in_bits == 0)
        log_file_error(current_filename, get_line_num(), "Illegal integer constant size of zero (IEEE 1800-2012, 5.7).\n");

    if (len > len_in_bits)
        log_warning("Literal has a width of %d bit, but value requires %d bit. (%s:%d)\n", len_in_bits, len, current_filename.c_str(),
                    get_line_num());
}

// convert the Verilog code for a constant to an AST node
AST::AstNode *const2ast(std::string code, char case_type, bool warn_z)
{
    if (warn_z) {
        AST::AstNode *ret = const2ast(code, case_type, false);
        if (ret != nullptr && std::find(ret->bits.begin(), ret->bits.end(), RTLIL::State::Sz) != ret->bits.end())
            log_warning("Yosys has only limited support for tri-state logic at the moment. (%s:%d)\n", current_filename.c_str(), get_line_num());
        return ret;
    }

    const char *str = code.c_str();

    // Strings
    if (*str == '"') {
        int len = strlen(str) - 2;
        std::vector<RTLIL::State> data;
        data.reserve(len * 8);
        for (int i = 0; i < len; i++) {
            unsigned char ch = str[len - i];
            for (int j = 0; j < 8; j++) {
                data.push_back((ch & 1) ? State::S1 : State::S0);
                ch = ch >> 1;
            }
        }
        AST::AstNode *ast = AST::AstNode::mkconst_bits(data, false);
        ast->str = code;
        return ast;
    }

    for (size_t i = 0; i < code.size(); i++)
        if (code[i] == '_' || code[i] == ' ' || code[i] == '\t' || code[i] == '\r' || code[i] == '\n')
            code.erase(code.begin() + (i--));
    str = code.c_str();

    char *endptr;
    long len_in_bits = strtol(str, &endptr, 10);

    // Simple base-10 integer
    if (*endptr == 0) {
        std::vector<RTLIL::State> data;
        my_strtobin(data, str, -1, 10, case_type, false);
        if (data.back() == State::S1)
            data.push_back(State::S0);
        return AST::AstNode::mkconst_bits(data, true);
    }

    // unsized constant
    if (str == endptr)
        len_in_bits = -1;

    // The "<bits>'[sS]?[bodhBODH]<digits>" syntax
    if (*endptr == '\'') {
        std::vector<RTLIL::State> data;
        bool is_signed = false;
        bool is_unsized = len_in_bits < 0;
        if (*(endptr + 1) == 's' || *(endptr + 1) == 'S') {
            is_signed = true;
            endptr++;
        }
        switch (*(endptr + 1)) {
        case 'b':
        case 'B':
            my_strtobin(data, endptr + 2, len_in_bits, 2, case_type, is_unsized);
            break;
        case 'o':
        case 'O':
            my_strtobin(data, endptr + 2, len_in_bits, 8, case_type, is_unsized);
            break;
        case 'd':
        case 'D':
            my_strtobin(data, endptr + 2, len_in_bits, 10, case_type, is_unsized);
            break;
        case 'h':
        case 'H':
            my_strtobin(data, endptr + 2, len_in_bits, 16, case_type, is_unsized);
            break;
        default:
            char next_char = char(tolower(*(endptr + 1)));
            if (next_char == '0' || next_char == '1' || next_char == 'x' || next_char == 'z') {
                is_unsized = true;
                my_strtobin(data, endptr + 1, 1, 2, case_type, is_unsized);
            } else {
                return NULL;
            }
        }
        if (len_in_bits < 0) {
            if (is_signed && data.back() == State::S1)
                data.push_back(State::S0);
        }
        return AST::AstNode::mkconst_bits(data, is_signed, is_unsized);
    }

    return NULL;
}
} // namespace VERILOG_FRONTEND

void UhdmAst::visit_range(vpiHandle obj_h, const std::function<void(AST::AstNode *)> &f)
{
    std::vector<AST::AstNode *> range_nodes;
    visit_one_to_many({vpiRange}, obj_h, [&](AST::AstNode *node) { range_nodes.push_back(node); });
    if (range_nodes.size() > 1) {
        auto multirange_node = new AST::AstNode(AST::AST_MULTIRANGE);
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
            visit_range(actual_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
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
    visit_range(obj_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
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
            current_node->children[0]->str += '.' + field_name;
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
        if (current_node->str == "\\" && !node->children.empty() && node->children[0]->type == AST::AST_RANGE) {
            current_node->type = AST::AST_PREFIX;
            current_node->str = node->str;
            current_node->children.push_back(node->children[0]->children[0]->clone());
            delete node;
        } else {
            if (current_node->type == AST::AST_IDENTIFIER) {
                if (current_node->str != "\\") {
                    current_node->str += ".";
                }
                current_node->str += node->str.substr(1);
                current_node->children = std::move(node->children);
                delete node;
            } else {
                current_node->children.push_back(node);
            }
        }
    });
}
