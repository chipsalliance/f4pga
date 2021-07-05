#include <cstring>
#include <vector>
#include <functional>
#include <algorithm>

#include "headers/uhdm.h"
#include "frontends/ast/ast.h"
#include "frontends/verilog/verilog_frontend.h"
#include "UhdmAst.h"
#include "vpi_user.h"
#include "libs/sha1/sha1.h"

YOSYS_NAMESPACE_BEGIN

static void sanitize_symbol_name(std::string &name) {
	if (!name.empty()) {
		auto pos = name.find_last_of("@");
		name = name.substr(pos+1);
		// symbol names must begin with '\'
		name.insert(0, "\\");
	}
}

static std::string strip_package_name(std::string name) {
	auto sep_index = name.find("::");
	if (sep_index != string::npos) {
		name = name.substr(sep_index + 1);
		name[0] = '\\';
	}
	return name;
}

void UhdmAst::visit_one_to_many(const std::vector<int> child_node_types,
								vpiHandle parent_handle,
								const std::function<void(AST::AstNode*)>& f) {
	for (auto child : child_node_types) {
		vpiHandle itr = vpi_iterate(child, parent_handle);
		while (vpiHandle vpi_child_obj = vpi_scan(itr) ) {
			UhdmAst uhdm_ast(this, shared, indent + "  ");
			auto *child_node = uhdm_ast.process_object(vpi_child_obj);
			f(child_node);
			vpi_free_object(vpi_child_obj);
		}
		vpi_free_object(itr);
	}
}

void UhdmAst::visit_one_to_one(const std::vector<int> child_node_types,
							   vpiHandle parent_handle,
							   const std::function<void(AST::AstNode*)>& f) {
	for (auto child : child_node_types) {
		vpiHandle itr = vpi_handle(child, parent_handle);
		if (itr) {
			UhdmAst uhdm_ast(this, shared, indent + "  ");
			auto *child_node = uhdm_ast.process_object(itr);
			f(child_node);
		}
		vpi_free_object(itr);
	}
}

void UhdmAst::visit_range(vpiHandle obj_h,
						  const std::function<void(AST::AstNode*)>& f)  {
	std::vector<AST::AstNode*> range_nodes;
	visit_one_to_many({vpiRange},
					  obj_h,
					  [&](AST::AstNode* node) {
						  range_nodes.push_back(node);
					  });
	if (range_nodes.size() > 1) {
		auto multirange_node = new AST::AstNode(AST::AST_MULTIRANGE);
		multirange_node->is_packed = true;
		multirange_node->children = range_nodes;
		f(multirange_node);
	} else if (!range_nodes.empty()) {
		f(range_nodes[0]);
	}
}

void UhdmAst::visit_default_expr(vpiHandle obj_h)  {
	if (vpi_handle(vpiExpr, obj_h)) {
		auto mod = find_ancestor({AST::AST_MODULE});
		AST::AstNode* initial_node = nullptr;
		AST::AstNode* block_node = nullptr;
		auto assign_node = new AST::AstNode(AST::AST_ASSIGN_EQ);
		auto id_node = new AST::AstNode(AST::AST_IDENTIFIER);
		id_node->str = current_node->str;

		for (auto child : mod->children) {
			if (child->type == AST::AST_INITIAL) {
				initial_node = child;
				break;
			}
		}
		// Ensure single AST_INITIAL node is located in AST_MODULE
		// before any AST_ALWAYS
		if (initial_node == nullptr) {
			initial_node = new AST::AstNode(AST::AST_INITIAL);

			auto insert_it = find_if(mod->children.begin(), mod->children.end(),
					[] (AST::AstNode *node) {return (node->type == AST::AST_ALWAYS);} );

			mod->children.insert(insert_it, 1, initial_node);
		}
		// Ensure single AST_BLOCK node in AST_INITIAL
		if (initial_node->children.size() && initial_node->children[0]) {
			block_node = initial_node->children[0];
		} else {
			block_node = new AST::AstNode(AST::AST_BLOCK);
			initial_node->children.push_back(block_node);
		}
		auto block_child = block_node->children.begin();
		for (;block_child != block_node->children.end(); block_child++) {
			if ((*block_child)->type == AST::AST_ASSIGN_EQ) {
				break;
			}
		}
		// Insert AST_ASSIGN_EQ nodes that came from
		// custom_var or int_var before any other AST_ASSIGN_EQ
		// Especially before ones explicitly placed in initial block in source code
		block_node->children.insert(block_child, 1, assign_node);
		assign_node->children.push_back(id_node);
		UhdmAst initial_ast(parent, shared, indent);
		initial_ast.current_node = initial_node;
		UhdmAst block_ast(&initial_ast, shared, indent);
		block_ast.current_node = block_node;
		block_ast.visit_one_to_one({vpiExpr},
								   obj_h,
								   [&](AST::AstNode* expr_node) {
									   assign_node->children.push_back(expr_node);
								   });
	}
}

AST::AstNode* UhdmAst::process_value(vpiHandle obj_h) {
	s_vpi_value val;
	vpi_get_value(obj_h, &val);
	std::string strValType;
	if (val.format) { // Needed to handle parameter nodes without typespecs and constants
		switch (val.format) {
			case vpiScalarVal: return AST::AstNode::mkconst_int(val.value.scalar, false, 1);
			case vpiBinStrVal: {
				strValType = "'b";
				break;
			}
			case vpiDecStrVal: {
				strValType = "'d";
				break;
			}
			case vpiHexStrVal: {
				strValType = "'h";
				break;
			}
                        // Surelog reports constant integers as a unsigned, but by default int is signed
                        // so we are treating here UInt in the same way as if they would be Int
                        case vpiUIntVal:
                        case vpiIntVal: {
				auto size = vpi_get(vpiSize, obj_h);
				auto c = AST::AstNode::mkconst_int(val.value.integer, true, size ? size : 64);
				if (size == 0) c->is_unsized = true;
				return c;
                        }
			case vpiRealVal: return AST::AstNode::mkconst_real(val.value.real);
			case vpiStringVal: return AST::AstNode::mkconst_str(val.value.str);
			default: {
				const uhdm_handle* const handle = (const uhdm_handle*) obj_h;
				const UHDM::BaseClass* const object = (const UHDM::BaseClass*) handle->object;
				report_error("Encountered unhandled constant format %d at %s:%d\n", val.format,
							 object->VpiFile().c_str(), object->VpiLineNo());
			}
		}
		// handle vpiBinStrVal, vpiDecStrVal and vpiHexStrVal
		if (std::strchr(val.value.str, '\'')) {
			return VERILOG_FRONTEND::const2ast(val.value.str, 0, false);
		} else {
			auto size = vpi_get(vpiSize, obj_h);
			if(size == 0 && strlen(val.value.str) == 1) {
				return AST::AstNode::mkconst_int(atoi(val.value.str), true, 1);
			}
			std::string size_str = "";
			if (size != 0) {
				size_str = std::to_string(size);
			}
			auto str = size_str + strValType + val.value.str;
			return VERILOG_FRONTEND::const2ast(str, 0, false);
		}
	}
	return nullptr;
}

AST::AstNode* UhdmAst::make_ast_node(AST::AstNodeType type, std::vector<AST::AstNode*> children) {
	auto node = new AST::AstNode(type);
	if (auto name = vpi_get_str(vpiName, obj_h)) {
		node->str = name;
	} else if (auto name = vpi_get_str(vpiDefName, obj_h)) {
		node->str = name;
	} else if (auto name = vpi_get_str(vpiFullName, obj_h)) {
		std::string s = std::string(name);
		if (s.rfind(".") != std::string::npos) {
			node->str = s.substr(s.rfind(".") + 1);
		} else {
			node->str = s;
		}
	}
	sanitize_symbol_name(node->str);
	if (auto filename = vpi_get_str(vpiFile, obj_h)) {
		node->filename = filename;
	}
	if (unsigned int line = vpi_get(vpiLineNo, obj_h)) {
		node->location.first_line = node->location.last_line = line;
	}
	const uhdm_handle* const handle = (const uhdm_handle*) obj_h;
	const UHDM::BaseClass* const object = (const UHDM::BaseClass*) handle->object;
	shared.visited[object] = node;
	node->children = children;
	return node;
}

static void add_or_replace_child(AST::AstNode* parent, AST::AstNode* child) {
	if (!child->str.empty()) {
		auto it = std::find_if(parent->children.begin(),
							   parent->children.end(),
							   [child](AST::AstNode* existing_child) {
								   return existing_child->str == child->str;
							   });
		if (it != parent->children.end()) {
			// If port direction is already set, copy it to replaced child node
			if((*it)->is_input || (*it)->is_output) {
				child->is_input = (*it)->is_input;
				child->is_output = (*it)->is_output;
				child->port_id = (*it)->port_id;
				child->type = AST::AST_WIRE;
			}
			if (!(*it)->children.empty() && child->children.empty()) {
				// This is a bit ugly, but if the child we're replacing has children and
				// our node doesn't, we copy its children to not lose any information
				for (auto grandchild : (*it)->children) {
					child->children.push_back(grandchild->clone());
					if (child->type == AST::AST_WIRE && grandchild->type == AST::AST_WIRETYPE)
						child->is_custom_type = true;
				}
			}
			// Special case for a wire with multirange
			if (child->children.size() > 1 && child->type == AST::AST_WIRE &&
				child->children[0]->type == AST::AST_RANGE && child->children[1]->type == AST::AST_RANGE) {
				auto multirange_node = new AST::AstNode(AST::AST_MULTIRANGE);
				multirange_node->is_packed = true;
				for (auto *c : child->children) {
					multirange_node->children.push_back(c->clone());
				}
				child->children.clear();
				child->children.push_back(multirange_node);
			}
			*it = child;
			return;
		}
		parent->children.push_back(child);
	} else if (child->type == AST::AST_INITIAL) {
		// Special case for initials
		// Ensure that there is only one AST_INITIAL in the design
		// And there is only one AST_BLOCK inside that initial
		// Copy nodes from child initial to parent initial
		auto initial_node_it = find_if(parent->children.begin(), parent->children.end(),
			[] (AST::AstNode *node) {return (node->type == AST::AST_INITIAL);} );
		if (initial_node_it != parent->children.end()) {
			AST::AstNode* initial_node = *initial_node_it;

			log_assert(!(initial_node->children.empty()));
			log_assert(initial_node->children[0]->type == AST::AST_BLOCK);
			log_assert(!(child->children.empty()));
			log_assert(child->children[0]->type == AST::AST_BLOCK);

			AST::AstNode* block_node = initial_node->children[0];
			AST::AstNode* child_block_node = child->children[0];

			// Place the contents of child block node inside parent block
			for (auto child_block_child : child_block_node->children)
				block_node->children.push_back(child_block_child->clone());
			// Place the remaining contents of child initial node inside the parent initial
			for (auto initial_child = child->children.begin() + 1; initial_child != child->children.end(); ++initial_child) {
				initial_node->children.push_back((*initial_child)->clone());
			}
		} else {
			// Parent AST_INITIAL does not exist
			// Place child AST_INITIAL before AST_ALWAYS if found
			auto insert_it = find_if(parent->children.begin(), parent->children.end(),
				[] (AST::AstNode *node) {return (node->type == AST::AST_ALWAYS);} );
			parent->children.insert(insert_it, 1, child);
		}
	} else {
		parent->children.push_back(child);
	}
}

void UhdmAst::make_cell(vpiHandle obj_h, AST::AstNode* cell_node, AST::AstNode* type_node) {
	if (cell_node->children.size() == 0 ||
			(cell_node->children.size() > 1 && cell_node->children[0]->type != AST::AST_CELLTYPE)) {
		auto typeNode = new AST::AstNode(AST::AST_CELLTYPE);
		typeNode->str = type_node->str;
		cell_node->children.insert(cell_node->children.begin(), typeNode);
	}
	// Add port connections as arguments
	vpiHandle port_itr = vpi_iterate(vpiPort, obj_h);
	while (vpiHandle port_h = vpi_scan(port_itr) ) {
		std::string arg_name;
		if (auto s = vpi_get_str(vpiName, port_h)) {
			arg_name = s;
			sanitize_symbol_name(arg_name);
		}
		auto arg_node = new AST::AstNode(AST::AST_ARGUMENT);
		arg_node->str = arg_name;
		arg_node->filename = cell_node->filename;
		arg_node->location = cell_node->location;
		visit_one_to_one({vpiHighConn},
						 port_h,
						 [&](AST::AstNode* node) {
						 	if (node) {
						 		arg_node->children.push_back(node);
						 	}
						 });
		cell_node->children.push_back(arg_node);
		shared.report.mark_handled(port_h);
		vpi_free_object(port_h);
	}
	vpi_free_object(port_itr);
}

void UhdmAst::add_typedef(AST::AstNode* current_node, AST::AstNode* type_node) {
	auto typedef_node = new AST::AstNode(AST::AST_TYPEDEF);
	typedef_node->location = type_node->location;
	typedef_node->filename = type_node->filename;
	typedef_node->str = strip_package_name(type_node->str);
	if (std::find(shared.type_names.begin(), shared.type_names.end(), std::make_pair(type_node->str, current_node->str)) != shared.type_names.end()) return;
	shared.type_names.push_back(std::make_pair(type_node->str, current_node->str));
	type_node = type_node->clone();
	if (type_node->type == AST::AST_STRUCT) {
		type_node->str.clear();
		typedef_node->children.push_back(type_node);
		current_node->children.push_back(typedef_node);
	} else if (type_node->type == AST::AST_ENUM) {
		type_node->str = "$enum" + std::to_string(shared.next_enum_id());
		for (auto* enum_item : type_node->children) {
			enum_item->attributes["\\enum_base_type"] = AST::AstNode::mkconst_str(type_node->str);
		}
		auto wire_node = new AST::AstNode(AST::AST_WIRE);
		wire_node->attributes["\\enum_type"] = AST::AstNode::mkconst_str(type_node->str);
		if (!type_node->children.empty() && type_node->children[0]->children.size() > 1) {
			wire_node->children.push_back(type_node->children[0]->children[1]->clone());
		}
		typedef_node->children.push_back(wire_node);
		current_node->children.push_back(type_node);
		current_node->children.push_back(typedef_node);
	} else {
		type_node->str.clear();
		typedef_node->children.push_back(type_node);
		current_node->children.push_back(typedef_node);
	}
}

AST::AstNode* UhdmAst::find_ancestor(const std::unordered_set<AST::AstNodeType>& types) {
	auto searched_node = this;
	while (searched_node) {
		if (searched_node->current_node) {
			if (types.find(searched_node->current_node->type) != types.end()) {
				return searched_node->current_node;
			}
		}
		searched_node = searched_node->parent;
	}
	return nullptr;
}


void UhdmAst::process_design() {
	current_node = make_ast_node(AST::AST_DESIGN);
	visit_one_to_many({UHDM::uhdmallInterfaces,
					   UHDM::uhdmallPackages,
					   UHDM::uhdmallModules,
					   UHDM::uhdmtopModules},
					  obj_h,
					  [&](AST::AstNode* node) {
						  if (node) {
							  shared.top_nodes[node->str] = node;
						  }
					  });
	// Once we walked everything, unroll that as children of this node
	for (auto pair : shared.top_nodes) {
		if (!pair.second) continue;
		if (!pair.second->get_bool_attribute(ID::partial)) {
			if (pair.second->type == AST::AST_PACKAGE)
				current_node->children.insert(current_node->children.begin(), pair.second);
			else
				current_node->children.push_back(pair.second);
		} else {
			log_warning("Removing module: %s from the design.\n", pair.second->str.c_str());
		}
	}
}

void UhdmAst::process_parameter() {
	auto type = vpi_get(vpiLocalParam, obj_h) == 1 ? AST::AST_LOCALPARAM : AST::AST_PARAMETER;
	current_node = make_ast_node(type);
	//if (vpi_get_str(vpiImported, obj_h) != "") { } //currently unused
	std::vector<AST::AstNode*> range_nodes;
	visit_range(obj_h,
			[&](AST::AstNode* node) {
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
				visit_range(typespec_h,
							[&](AST::AstNode* node) {
								range_nodes.push_back(node);
							});
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
				visit_one_to_one({vpiTypespec},
								 obj_h,
								 [&](AST::AstNode* node) {
									 shared.param_types[current_node->str] = node;
								 });
				break;
			}
			default: {
				const uhdm_handle* const handle = (const uhdm_handle*) typespec_h;
				const UHDM::BaseClass* const object = (const UHDM::BaseClass*) handle->object;
				report_error("Encountered unhandled typespec in process_parameter: '%s' of type '%s' at %s:%d\n",
							 object->VpiName().c_str(), UHDM::VpiTypeName(typespec_h).c_str(), object->VpiFile().c_str(),
							 object->VpiLineNo());
				break;
			}
		}
	} else {
		AST::AstNode* constant_node = process_value(obj_h);
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

void UhdmAst::process_port() {
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
				visit_range(actual_h,
							[&](AST::AstNode* node) {
								if (node->type == AST::AST_MULTIRANGE) node->is_packed = true;
								current_node->children.push_back(node);
							});
				shared.report.mark_handled(actual_h);
				break;
			}
			case vpiPackedArrayVar:
				visit_one_to_many({vpiElement},
								  actual_h,
								  [&](AST::AstNode* node) {
									  if (node && GetSize(node->children) == 1)
										  current_node->children.push_back(node->children[0]);
								  });
				visit_one_to_many({vpiRange},
								  actual_h,
								  [&](AST::AstNode* node) {
									  current_node->children.push_back(node);
								  });
				shared.report.mark_handled(actual_h);
				break;
			case vpiPackedArrayNet:
				visit_one_to_many({vpiRange},
								  actual_h,
								  [&](AST::AstNode* node) {
									  current_node->children.push_back(node);
								  });
				shared.report.mark_handled(actual_h);
				break;
			case vpiArrayVar:
				visit_one_to_many({vpiRange}, actual_h, [&](AST::AstNode* node) {
					current_node->children.push_back(node);
				});
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
				const uhdm_handle* const handle = (const uhdm_handle*) actual_h;
				const UHDM::BaseClass* const object = (const UHDM::BaseClass*) handle->object;
				report_error("Encountered unhandled type in process_port: %s at %s:%d\n", UHDM::VpiTypeName(actual_h).c_str(),
							 object->VpiFile().c_str(), object->VpiLineNo());
				break;
			}
		}
		shared.report.mark_handled(lowConn_h);
	}
	visit_one_to_one({vpiTypedef},
					 obj_h,
					 [&](AST::AstNode* node) {
					 	 if (node && node->str != "") {
							 auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
							 wiretype_node->str = node->str;
							 // wiretype needs to be 1st node (if port have also another range nodes)
							 current_node->children.insert(current_node->children.begin(), wiretype_node);
							 current_node->is_custom_type=true;
						 } else {
						 	// anonymous typedef, just move childrens
							for (auto child : node->children) {
								current_node->children.push_back(child->clone());
							}
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

void UhdmAst::process_module() {
	std::string type = vpi_get_str(vpiDefName, obj_h);
	std::string name = vpi_get_str(vpiName, obj_h) ? vpi_get_str(vpiName, obj_h) : type;
	bool cell_instance = type == name;
	sanitize_symbol_name(type);
	sanitize_symbol_name(name);
	type = strip_package_name(type);
	name = strip_package_name(name);
	if (cell_instance) {
		if (shared.top_nodes.find(type) != shared.top_nodes.end()) {
			current_node = shared.top_nodes[type];
			visit_one_to_many({vpiModule,
							   vpiInterface,
							   vpiParameter,
							   vpiParamAssign,
							   vpiPort,
							   vpiNet,
							   vpiArrayNet,
							   vpiGenScopeArray,
							   vpiContAssign,
							   vpiVariables},
							  obj_h,
							  [&](AST::AstNode* node) {
								  if (node) {
									  add_or_replace_child(current_node, node);
								  }
							  });
			current_node->attributes.erase(ID::partial);
		} else {
			current_node = make_ast_node(AST::AST_MODULE);
			current_node->str = type;
			shared.top_nodes[current_node->str] = current_node;
			current_node->attributes[ID::partial] = AST::AstNode::mkconst_int(1, false, 1);
			visit_one_to_many({vpiTypedef},
							  obj_h,
							  [&](AST::AstNode* node) {
								  if (node) {
									  add_typedef(current_node, node);
								  }
							  });
			visit_one_to_many({vpiModule,
							   vpiInterface,
							   vpiParameter,
							   vpiParamAssign,
							   vpiPort,
							   vpiNet,
							   vpiArrayNet,
							   vpiGenScopeArray,
							   vpiContAssign,
							   vpiProcess,
							   vpiTaskFunc},
							  obj_h,
							  [&](AST::AstNode* node) {
								  if (node) {
									  if (node->type == AST::AST_ASSIGN && node->children.size() < 2) return;
									  add_or_replace_child(current_node, node);
								  }
							  });
		}
	} else {
		// Not a top module, create instance
		current_node = make_ast_node(AST::AST_CELL);
		auto module_node = shared.top_nodes[type];
		if (!module_node) {
			module_node = shared.top_node_templates[type];
			if (!module_node) {
				module_node = new AST::AstNode(AST::AST_MODULE);
				module_node->str = type;
				module_node->attributes[ID::partial] = AST::AstNode::mkconst_int(2, false, 1);
			}
			shared.top_nodes[module_node->str] = module_node;
		}
		module_node = module_node->clone();
		auto cell_instance = vpi_get(vpiCellInstance, obj_h);
		if (cell_instance) {
			module_node->attributes[ID::whitebox] = AST::AstNode::mkconst_int(1, false, 1);
		}
		//TODO: setting keep attribute probably shouldn't be needed,
		// but without this, modules that are generated in genscope are removed
		// for now lets just add this attribute
		module_node->attributes[ID::keep] = AST::AstNode::mkconst_int(1, false, 1);
		if (module_node->attributes.count(ID::partial)) {
			AST::AstNode *attr = module_node->attributes.at(ID::partial);
			if (attr->type == AST::AST_CONSTANT)
				if (attr->integer == 1)
					module_node->attributes.erase(ID::partial);
		}
		std::string module_parameters;
		visit_one_to_many({vpiParamAssign},
						  obj_h,
						  [&](AST::AstNode* node) {
							  if (node) {
							  	auto parent_node = std::find_if(module_node->children.begin(), module_node->children.end(),
								                   		[&](AST::AstNode *child)->bool { return ((child->type == AST::AST_PARAMETER) || (child->type == AST::AST_LOCALPARAM)) &&
								                       		                                        child->str == node->str &&
								                       							//skip real parameters as they are currently not working: https://github.com/alainmarcel/Surelog/issues/1035
								                       							child->type != AST::AST_REALVALUE;});
								 if (parent_node != module_node->children.end()) {
									if ((*parent_node)->type == AST::AST_PARAMETER) {
										if (cell_instance || (node->children.size() > 0 && node->children[0]->type != AST::AST_CONSTANT)) { //if cell is a blackbox or we need to simplify parameter first, left setting parameters to yosys
											// We only want to add AST_PARASET for parameters that is different than already set
											// to match the name yosys gives to the module.
											// Note: this should also be applied for other (not only cell_instance) modules
											// but as we are using part of the modules parsed by sv2v and other
											// part by uhdm, we need to always rename module if it is parametrized,
											// Otherwise, verilog frontend can use module parsed by uhdm and try to set
											// parameters, but this module would be already parametrized
											if ((node->children[0]->integer != (*parent_node)->children[0]->integer ||
                                                                                             node->children[0]->str != (*parent_node)->children[0]->str)) {
												auto clone = node->clone();
												clone->type = AST::AST_PARASET;
												current_node->children.push_back(clone);
											}
										} else {
											if (node->children[0]->str != "")
												module_parameters += node->str + "=" + node->children[0]->str;
											else
												module_parameters += node->str + "=" + std::to_string(node->children[0]->integer);
											//replace
											add_or_replace_child(module_node, node);
										}
									} else {
										add_or_replace_child(module_node, node);
									}
								}
							  }
						  });
		//rename module in same way yosys do
		if (module_parameters.size() > 60)
			module_node->str = "$paramod$" + sha1(module_parameters) + type;
		else if(module_parameters != "")
			module_node->str = "$paramod" + type + module_parameters;
		auto typeNode = new AST::AstNode(AST::AST_CELLTYPE);
		typeNode->str = module_node->str;
		current_node->children.insert(current_node->children.begin(), typeNode);
		shared.top_node_templates[module_node->str] = module_node;
		shared.top_nodes[module_node->str] = module_node;
		visit_one_to_many({vpiVariables,
						   vpiNet,
						   vpiArrayNet},
						  obj_h,
						  [&](AST::AstNode* node) {
							  if (node) {
								add_or_replace_child(module_node, node);
							  }
						  });
		visit_one_to_many({vpiInterface,
						   vpiModule,
						   vpiPort,
						   vpiGenScopeArray},
						  obj_h,
						  [&](AST::AstNode* node) {
							  if (node) {
								  add_or_replace_child(module_node, node);
							  }
						  });
		make_cell(obj_h, current_node, module_node);
	}
}

void UhdmAst::process_struct_typespec() {
	current_node = make_ast_node(AST::AST_STRUCT);
	visit_one_to_many({vpiTypespecMember},
					  obj_h,
					  [&](AST::AstNode* node) {
						  current_node->children.push_back(node);
					  });
}

void UhdmAst::process_packed_array_typespec() {
	current_node = make_ast_node(AST::AST_WIRE);
	visit_one_to_one({vpiElemTypespec},
					  obj_h,
					  [&](AST::AstNode* node) {
					  	if (node) {
							current_node->str = node->str;
						}
					  });
}

void UhdmAst::process_typespec_member() {
	current_node = make_ast_node(AST::AST_STRUCT_ITEM);
	current_node->str = current_node->str.substr(1);
	vpiHandle typespec_h = vpi_handle(vpiTypespec, obj_h);
	int typespec_type = vpi_get(vpiType, typespec_h);
	switch (typespec_type) {
		case vpiBitTypespec:
		case vpiLogicTypespec: {
			current_node->is_logic = true;
			visit_range(typespec_h,
						[&](AST::AstNode* node) {
							current_node->children.push_back(node);
						});
			shared.report.mark_handled(typespec_h);
			break;
		}
		case vpiIntTypespec: {
			current_node->is_signed = true;
			shared.report.mark_handled(typespec_h);
			break;
		}
		case vpiStructTypespec:
		case vpiEnumTypespec: {
			visit_one_to_one({vpiTypespec},
							 obj_h,
							 [&](AST::AstNode* node) {
								 if (typespec_type == vpiStructTypespec) {
									 auto str = current_node->str;
									 node->cloneInto(current_node);
									 current_node->str = str;
								 } else if (typespec_type == vpiEnumTypespec) {
									 current_node->children.push_back(node);
								 }
							 });
			break;
		}
		case vpiPackedArrayTypespec:
			visit_one_to_one({vpiTypespec},
							  obj_h,
							  [&](AST::AstNode* node) {
								if (node) {
									current_node->str = node->str;
								}
							  });
			break;
		default: {
			const uhdm_handle* const handle = (const uhdm_handle*) typespec_h;
			const UHDM::BaseClass* const object = (const UHDM::BaseClass*) handle->object;
			report_error("Encountered unhandled typespec in process_typespec_member: '%s' of type '%s' at %s:%d\n",
						 object->VpiName().c_str(), UHDM::VpiTypeName(typespec_h).c_str(), object->VpiFile().c_str(),
						 object->VpiLineNo());
			break;
		}
	}
}

void UhdmAst::process_enum_typespec() {
	current_node = make_ast_node(AST::AST_ENUM);
	visit_one_to_many({vpiEnumConst},
					  obj_h,
					  [&](AST::AstNode* node) {
						  current_node->children.push_back(node);
					  });
	vpiHandle typespec_h = vpi_handle(vpiBaseTypespec, obj_h);
	if (typespec_h) {
		int typespec_type = vpi_get(vpiType, typespec_h);
		switch (typespec_type) {
			case vpiLogicTypespec: {
				current_node->is_logic = true;
				visit_range(typespec_h,
							[&](AST::AstNode* node) {
								for (auto child : current_node->children) {
									child->children.push_back(node->clone());
								}
							});
				shared.report.mark_handled(typespec_h);
				break;
			}
			case vpiIntTypespec: {
				current_node->is_signed = true;
				shared.report.mark_handled(typespec_h);
				break;
			}
			default: {
				const uhdm_handle* const handle = (const uhdm_handle*) typespec_h;
				const UHDM::BaseClass* const object = (const UHDM::BaseClass*) handle->object;
				report_error("Encountered unhandled typespec in process_enum_typespec: '%s' of type '%s' at %s:%d\n",
							 object->VpiName().c_str(), UHDM::VpiTypeName(typespec_h).c_str(), object->VpiFile().c_str(),
							 object->VpiLineNo());
				break;
			}
		}
	}
}

void UhdmAst::process_enum_const() {
	current_node = make_ast_node(AST::AST_ENUM_ITEM);
	AST::AstNode* constant_node = process_value(obj_h);
	if (constant_node) {
		constant_node->filename = current_node->filename;
		constant_node->location = current_node->location;
		current_node->children.push_back(constant_node);
	}
}

void UhdmAst::process_custom_var() {
	current_node = make_ast_node(AST::AST_WIRE);
	visit_one_to_one({vpiTypespec},
					 obj_h,
					 [&](AST::AstNode* node) {
						 if (node->str.empty()) {
							 // anonymous typespec, move the children to variable
							 current_node->type = node->type;
							 current_node->children = std::move(node->children);
						 } else {
						 	 // custom var in gen scope have definition with declaration
							 auto *parent = find_ancestor({AST::AST_GENBLOCK, AST::AST_BLOCK});
						 	 if (parent && std::find(shared.type_names.begin(), shared.type_names.end(), std::make_pair(node->str, parent->str)) == shared.type_names.end() && node->children.size() > 0) {
							     add_typedef(parent, node);
							 }
							 auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
							 wiretype_node->str = node->str;
							 current_node->children.push_back(wiretype_node);
						 }
					 });
	auto type = vpi_get(vpiType, obj_h);
	if (type == vpiEnumVar || type == vpiStructVar) {
		visit_default_expr(obj_h);
	}
	current_node->is_custom_type = true;
}

void UhdmAst::process_int_var() {
	current_node = make_ast_node(AST::AST_WIRE);
	auto left_const = AST::AstNode::mkconst_int(31, true);
	auto right_const = AST::AstNode::mkconst_int(0, true);
	auto range = new AST::AstNode(AST::AST_RANGE, left_const, right_const);
	current_node->children.push_back(range);
	current_node->is_signed = true;
	visit_default_expr(obj_h);
}

void UhdmAst::process_real_var() {
	auto module_node = find_ancestor({AST::AST_MODULE});
	auto wire_node = make_ast_node(AST::AST_WIRE);
	auto left_const = AST::AstNode::mkconst_int(63, true);
	auto right_const = AST::AstNode::mkconst_int(0, true);
	auto range = new AST::AstNode(AST::AST_RANGE, left_const, right_const);
	wire_node->children.push_back(range);
	wire_node->is_signed = true;
	module_node->children.push_back(wire_node);
	current_node = make_ast_node(AST::AST_IDENTIFIER);
	visit_default_expr(obj_h);
}

void UhdmAst::process_array_var() {
	current_node = make_ast_node(AST::AST_WIRE);
	vpiHandle itr = vpi_iterate(vpi_get(vpiType, obj_h) == vpiArrayVar ?
								vpiReg : vpiElement, obj_h);
	while (vpiHandle reg_h = vpi_scan(itr)) {
		if (vpi_get(vpiType, reg_h) == vpiStructVar || vpi_get(vpiType, reg_h) == vpiEnumVar) {
			vpiHandle typespec_h = vpi_handle(vpiTypespec, reg_h);
			std::string name = vpi_get_str(vpiName, typespec_h);
			sanitize_symbol_name(name);
			auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
			wiretype_node->str = name;
			current_node->children.push_back(wiretype_node);
			current_node->is_custom_type = true;
			shared.report.mark_handled(reg_h);
			shared.report.mark_handled(typespec_h);
		}
		vpi_free_object(reg_h);
	}
	vpi_free_object(itr);
	visit_one_to_many({vpiRange},
					obj_h,
					[&](AST::AstNode* node) {
						current_node->children.push_back(node);
					});
}

void UhdmAst::process_param_assign() {
	current_node = make_ast_node(AST::AST_PARAMETER);
	visit_one_to_one({vpiLhs},
					 obj_h,
					 [&](AST::AstNode* node) {
						 if (node) {
						 	 current_node->type = node->type;
							 current_node->str = node->str;
							 //Here we need to copy any ranges that is already present in lhs,
							 //but we want to skip actual value, as it is set in rhs
							 for (auto *c : node->children) {
							 	if(c->type != AST::AST_CONSTANT) {
									current_node->children.push_back(c->clone());
								}
							 }
							 shared.param_types[current_node->str] = shared.param_types[node->str];
						 }
					 });
	visit_one_to_one({vpiRhs},
					 obj_h,
					 [&](AST::AstNode* node) {
						 if (node) {
							 current_node->children.insert(current_node->children.begin(), node);
						 }
					 });
}

void UhdmAst::process_cont_assign_var_init() {
	current_node = make_ast_node(AST::AST_INITIAL);
	auto block_node = make_ast_node(AST::AST_BLOCK);
	auto assign_node = make_ast_node(AST::AST_ASSIGN_LE);
	block_node->children.push_back(assign_node);
	current_node->children.push_back(block_node);

	visit_one_to_one({vpiLhs,
					  vpiRhs},
					 obj_h,
					 [&](AST::AstNode* node) {
						 if (node) {
							 if (node->type == AST::AST_WIRE) {
								 assign_node->children.push_back(new AST::AstNode(AST::AST_IDENTIFIER));
								 assign_node->children.back()->str = node->str;
							 } else {
								 assign_node->children.push_back(node);
							 }
						 }
					 });
}

void UhdmAst::process_cont_assign_net() {
	current_node = make_ast_node(AST::AST_ASSIGN);

	visit_one_to_one({vpiLhs,
					  vpiRhs},
					 obj_h,
					 [&](AST::AstNode* node) {
						 if (node) {
							 if (node->type == AST::AST_WIRE) {
								 current_node->children.push_back(new AST::AstNode(AST::AST_IDENTIFIER));
								 current_node->children.back()->str = node->str;
							 } else {
								 current_node->children.push_back(node);
							 }
						 }
					 });
}

void UhdmAst::process_cont_assign() {
	auto net_decl_assign = vpi_get(vpiNetDeclAssign, obj_h);
	vpiHandle node_lhs_h = vpi_handle(vpiLhs, obj_h);
	auto lhs_net_type = vpi_get(vpiNetType, node_lhs_h);

	// Check if lhs is a subtype of a net
	bool isNet;
	if (lhs_net_type >= vpiWire && lhs_net_type <= vpiUwire)
		isNet = true;
	else
		// lhs is a variable
		isNet = false;
	if (net_decl_assign && !isNet)
		process_cont_assign_var_init();
	else
		process_cont_assign_net();
}

void UhdmAst::process_assignment() {
	auto type = vpi_get(vpiBlocking, obj_h) == 1 ? AST::AST_ASSIGN_EQ : AST::AST_ASSIGN_LE;
	current_node = make_ast_node(type);
	visit_one_to_one({vpiLhs,
					  vpiRhs},
					 obj_h,
					 [&](AST::AstNode* node) {
						 if (node) {
							 current_node->children.push_back(node);
						 }
					 });
	if (current_node->children.size() == 1 && current_node->children[0]->type == AST::AST_WIRE) {
		  auto top_node = find_ancestor({AST::AST_MODULE});
		  if (!top_node) return;
		  top_node->children.push_back(current_node->children[0]->clone());
		  current_node = nullptr;
	}
}

void UhdmAst::process_net() {
	current_node = make_ast_node(AST::AST_WIRE);
	auto net_type = vpi_get(vpiNetType, obj_h);
	current_node->is_reg = net_type == vpiReg;
	current_node->is_output = net_type == vpiOutput;
	current_node->is_logic = !current_node->is_reg;
	current_node->is_signed = vpi_get(vpiSigned, obj_h);
	visit_one_to_one({vpiTypespec},
					 obj_h,
					 [&](AST::AstNode* node) {
					 	 if (node) {
							 auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
							 wiretype_node->str = node->str;
							 // wiretype needs to be 1st node
							 current_node->children.insert(current_node->children.begin(), wiretype_node);
							 current_node->is_custom_type=true;
						 }
					 });
	visit_range(obj_h,
				[&](AST::AstNode* node) {
					current_node->children.push_back(node);
					if (node->type == AST::AST_MULTIRANGE) {
						node->is_packed = true;
					}
				});
}

void UhdmAst::process_packed_array_net() {
	current_node = make_ast_node(AST::AST_WIRE);
	visit_one_to_many({vpiElement},
					  obj_h,
					  [&](AST::AstNode* node) {
						  if (node && GetSize(node->children) == 1)
							  current_node->children.push_back(node->children[0]);
						  current_node->is_custom_type = node->is_custom_type;
					  });
	visit_one_to_many({vpiRange},
					  obj_h,
					  [&](AST::AstNode* node) {
						  current_node->children.push_back(node);
					  });
}
void UhdmAst::process_array_net() {
	current_node = make_ast_node(AST::AST_WIRE);
	vpiHandle itr = vpi_iterate(vpiNet, obj_h);
	while (vpiHandle net_h = vpi_scan(itr)) {
		auto net_type = vpi_get(vpiType, net_h);
		if (net_type == vpiLogicNet) {
			current_node->is_logic = true;
			current_node->is_signed = vpi_get(vpiSigned, net_h);
			visit_range(net_h,
						[&](AST::AstNode* node) {
							current_node->children.push_back(node);
						});
			shared.report.mark_handled(net_h);
		} else if (net_type == vpiStructNet) {
                        vpiHandle typespec_h = vpi_handle(vpiTypespec, net_h);
                        std::string name = vpi_get_str(vpiName, typespec_h);
                        sanitize_symbol_name(name);
                        auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
                        wiretype_node->str = name;
                        current_node->children.push_back(wiretype_node);
                        current_node->is_custom_type = true;
                        shared.report.mark_handled(net_h);
                        shared.report.mark_handled(typespec_h);
		}
		vpi_free_object(net_h);
	}
	vpi_free_object(itr);
	visit_one_to_many({vpiRange},
					  obj_h,
					  [&](AST::AstNode* node) {
						  current_node->children.push_back(node);
					  });
	if (current_node->children.size() == 2) { // If there is 2 ranges, change type to AST_MEMORY
		current_node->type = AST::AST_MEMORY;
	}
}

void UhdmAst::process_package() {
	current_node = make_ast_node(AST::AST_PACKAGE);
	visit_one_to_many({vpiParameter,
					   vpiParamAssign},
					  obj_h,
					  [&](AST::AstNode* node) {
						  if (node) {
							  add_or_replace_child(current_node, node);
						  }
					  });
	visit_one_to_many({vpiTypedef},
					  obj_h,
					  [&](AST::AstNode* node) {
						  if (node) {
							  add_typedef(current_node, node);
						  }
					  });
	visit_one_to_many({vpiTaskFunc},
					  obj_h,
					  [&](AST::AstNode* node) {
						  if (node) {
							  current_node->children.push_back(node);
						  }
					  });
}

void UhdmAst::process_interface() {
	std::string type = vpi_get_str(vpiDefName, obj_h);
	std::string name = vpi_get_str(vpiName, obj_h) ? vpi_get_str(vpiName, obj_h) : type;
	sanitize_symbol_name(type);
	sanitize_symbol_name(name);
	AST::AstNode* elaboratedInterface;
	// Check if we have encountered this object before
	if (shared.top_nodes.find(type) != shared.top_nodes.end()) {
		// Was created before, fill missing
		elaboratedInterface = shared.top_nodes[type];
		visit_one_to_many({vpiPort},
						  obj_h,
						  [&](AST::AstNode* node) {
							  if (node) {
								  add_or_replace_child(elaboratedInterface, node);
							  }
						  });
	} else {
		// Encountered for the first time
		elaboratedInterface = new AST::AstNode(AST::AST_INTERFACE);
		elaboratedInterface->str = name;
		visit_one_to_many({vpiNet,
						   vpiPort,
						   vpiModport},
						   obj_h,
						   [&](AST::AstNode* node) {
							   if (node) {
								   add_or_replace_child(elaboratedInterface, node);
							   }
						   });
	}
	shared.top_nodes[elaboratedInterface->str] = elaboratedInterface;
	if (name != type) {
		// Not a top module, create instance
		current_node = make_ast_node(AST::AST_CELL);
		make_cell(obj_h, current_node, elaboratedInterface);
	} else {
		current_node = elaboratedInterface;
	}
}

void UhdmAst::process_modport() {
	current_node = make_ast_node(AST::AST_MODPORT);
	visit_one_to_many({vpiIODecl},
					  obj_h,
					  [&](AST::AstNode* node) {
						  if (node) {
							  current_node->children.push_back(node);
						  }
					  });
}

void UhdmAst::process_io_decl() {
	current_node = nullptr;
	visit_one_to_one({vpiExpr},
					 obj_h,
					 [&](AST::AstNode* node) {
					 	 current_node = node;
					 });
	if (current_node == nullptr) {
		current_node = make_ast_node(AST::AST_MODPORTMEMBER);
		visit_range(obj_h,
					[&](AST::AstNode* node) {
						current_node->children.push_back(node);
					});
	}
	visit_one_to_one({vpiTypedef},
					 obj_h,
					 [&](AST::AstNode* node) {
					 	 if (node && node->str != "") {
							 auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
							 wiretype_node->str = node->str;
							 // wiretype needs to be 1st node (if port have also another range nodes)
							 current_node->children.insert(current_node->children.begin(), wiretype_node);
							 current_node->is_custom_type=true;
						 } else {
						 	// anonymous typedef, just move childrens
							for (auto child : node->children) {
								current_node->children.push_back(child->clone());
							}
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

void UhdmAst::process_always() {
	current_node = make_ast_node(AST::AST_ALWAYS);
	visit_one_to_one({vpiStmt},
		obj_h,
		[&](AST::AstNode* node) {
			if (node) {
				AST::AstNode* block = nullptr;
				if (node->type != AST::AST_BLOCK) {
					block = new AST::AstNode(AST::AST_BLOCK, node);
				} else {
					block = node;
				}
				current_node->children.push_back(block);
			}
		});
	switch (vpi_get(vpiAlwaysType, obj_h)) {
		case vpiAlwaysComb:
			current_node->attributes[ID::always_comb] = AST::AstNode::mkconst_int(1, false); break;
		case vpiAlwaysFF:
			current_node->attributes[ID::always_ff] = AST::AstNode::mkconst_int(1, false); break;
		case vpiAlwaysLatch:
			current_node->attributes[ID::always_latch] = AST::AstNode::mkconst_int(1, false); break;
		default:
			break;
	}
}

void UhdmAst::process_event_control() {
	current_node = make_ast_node(AST::AST_BLOCK);
	visit_one_to_one({vpiCondition},
					 obj_h,
					 [&](AST::AstNode* node) {
						 if (node) {
							 auto process_node = find_ancestor({AST::AST_ALWAYS});
							 process_node->children.push_back(node);
						 }
						 // is added inside vpiOperation
					 });
	visit_one_to_one({vpiStmt},
					 obj_h,
					 [&](AST::AstNode* node) {
						 if (node) {
							 current_node->children.push_back(node);
						 }
					 });
}

void UhdmAst::process_initial() {
	current_node = make_ast_node(AST::AST_INITIAL);
	visit_one_to_one({vpiStmt},
					 obj_h,
					 [&](AST::AstNode* node) {
						 if (node) {
							 if (node->type != AST::AST_BLOCK) {
								 auto block_node = make_ast_node(AST::AST_BLOCK);
								 block_node->children.push_back(node);
								 node = block_node;
							 }
							 current_node->children.push_back(node);
						 }
					 });
}

void UhdmAst::process_begin() {
	current_node = make_ast_node(AST::AST_BLOCK);
	visit_one_to_many({vpiStmt},
					  obj_h,
					  [&](AST::AstNode* node) {
						  if (node) {
							  if ((node->type == AST::AST_ASSIGN_EQ || node->type == AST::AST_ASSIGN_LE) && node->children.size() == 1) {
								  auto func_node = find_ancestor({AST::AST_FUNCTION, AST::AST_TASK});
								  if (!func_node) return;
								  auto wire_node = new AST::AstNode(AST::AST_WIRE);
								  wire_node->type = AST::AST_WIRE;
								  wire_node->str = node->children[0]->str;
								  func_node->children.push_back(wire_node);
							  } else {
								  current_node->children.push_back(node);
							  }
						  }
					  });
}

void UhdmAst::process_operation() {
	auto operation = vpi_get(vpiOpType, obj_h);
	switch (operation) {
		case vpiStreamRLOp: process_stream_op(); break;
		case vpiEventOrOp:
		case vpiListOp: process_list_op(); break;
		case vpiCastOp: process_cast_op(); break;
		case vpiInsideOp: process_inside_op(); break;
		case vpiAssignmentPatternOp: process_assignment_pattern_op(); break;
		default: {
			current_node = make_ast_node(AST::AST_NONE);
			visit_one_to_many({vpiOperand},
							  obj_h,
							  [&](AST::AstNode* node) {
								  if (node) {
									current_node->children.push_back(node);
								  }
							  });
			switch(operation) {
				case vpiMinusOp: current_node->type = AST::AST_NEG; break;
				case vpiPlusOp: current_node->type = AST::AST_POS; break;
				case vpiPosedgeOp: current_node->type = AST::AST_POSEDGE; break;
				case vpiNegedgeOp: current_node->type = AST::AST_NEGEDGE; break;
				case vpiUnaryAndOp: current_node->type = AST::AST_REDUCE_AND; break;
				case vpiUnaryOrOp: current_node->type = AST::AST_REDUCE_OR; break;
				case vpiUnaryXorOp: current_node->type = AST::AST_REDUCE_XOR; break;
				case vpiUnaryXNorOp: current_node->type = AST::AST_REDUCE_XNOR; break;
				case vpiUnaryNandOp: {
					current_node->type = AST::AST_REDUCE_AND;
					auto not_node = new AST::AstNode(AST::AST_LOGIC_NOT, current_node);
					current_node = not_node;
					break;
				}
				case vpiUnaryNorOp: {
					current_node->type = AST::AST_REDUCE_OR;
					auto not_node = new AST::AstNode(AST::AST_LOGIC_NOT, current_node);
					current_node = not_node;
					break;
				}
				case vpiBitNegOp: current_node->type = AST::AST_BIT_NOT; break;
				case vpiBitAndOp: current_node->type = AST::AST_BIT_AND; break;
				case vpiBitOrOp: current_node->type = AST::AST_BIT_OR; break;
				case vpiBitXorOp: current_node->type = AST::AST_BIT_XOR; break;
				case vpiBitXnorOp: current_node->type = AST::AST_BIT_XNOR; break;
				case vpiLShiftOp: current_node->type = AST::AST_SHIFT_LEFT; break;
				case vpiRShiftOp: current_node->type = AST::AST_SHIFT_RIGHT; break;
				case vpiNotOp: current_node->type = AST::AST_LOGIC_NOT; break;
				case vpiLogAndOp: current_node->type = AST::AST_LOGIC_AND; break;
				case vpiLogOrOp: current_node->type = AST::AST_LOGIC_OR; break;
				case vpiEqOp: current_node->type = AST::AST_EQ; break;
				case vpiNeqOp: current_node->type = AST::AST_NE; break;
				case vpiGtOp: current_node->type = AST::AST_GT; break;
				case vpiGeOp: current_node->type = AST::AST_GE; break;
				case vpiLtOp: current_node->type = AST::AST_LT; break;
				case vpiLeOp: current_node->type = AST::AST_LE; break;
				case vpiSubOp: current_node->type = AST::AST_SUB; break;
				case vpiAddOp: current_node->type = AST::AST_ADD; break;
				case vpiMultOp: current_node->type = AST::AST_MUL; break;
				case vpiDivOp: current_node->type = AST::AST_DIV; break;
				case vpiModOp: current_node->type = AST::AST_MOD; break;
				case vpiArithLShiftOp: current_node->type = AST::AST_SHIFT_SLEFT; break;
				case vpiArithRShiftOp: current_node->type = AST::AST_SHIFT_SRIGHT; break;
				case vpiPowerOp: current_node->type = AST::AST_POW; break;
				case vpiPostIncOp: // TODO: Make this an actual post-increment op (currently it's a pre-increment)
				case vpiPreIncOp: {
					current_node->type = AST::AST_ASSIGN_EQ;
					auto id = current_node->children[0]->clone();
					auto add_node = new AST::AstNode(AST::AST_ADD, id, AST::AstNode::mkconst_int(1, true));
					add_node->filename = current_node->filename;
					add_node->location = current_node->location;
					current_node->children.push_back(add_node);
					break;
				}
				case vpiPostDecOp: // TODO: Make this an actual post-decrement op (currently it's a pre-decrement)
				case vpiPreDecOp: {
					current_node->type = AST::AST_ASSIGN_EQ;
					auto id = current_node->children[0]->clone();
					auto add_node = new AST::AstNode(AST::AST_SUB, id, AST::AstNode::mkconst_int(1, true));
					add_node->filename = current_node->filename;
					add_node->location = current_node->location;
					current_node->children.push_back(add_node);
					break;
				}
				case vpiConditionOp: current_node->type = AST::AST_TERNARY; break;
				case vpiConcatOp: {
					current_node->type = AST::AST_CONCAT;
					std::reverse(current_node->children.begin(), current_node->children.end());
					break;
				}
				case vpiMultiConcatOp: current_node->type = AST::AST_REPLICATE; break;
				case vpiAssignmentOp: current_node->type = AST::AST_ASSIGN_EQ; break;
				case vpiStreamLROp: {
					auto concat_node = current_node->children.back();
					current_node->children.pop_back();
					delete current_node;
					current_node = concat_node;
					break;
				}
				case vpiNullOp: current_node = nullptr; break; //do nothing
				default: {
					const uhdm_handle* const handle = (const uhdm_handle*) obj_h;
					const UHDM::BaseClass* const object = (const UHDM::BaseClass*) handle->object;
					report_error("Encountered unhandled operation type %d at %s:%d\n", operation,
								 object->VpiFile().c_str(), object->VpiLineNo());
				}
			}
		}
	}
}

void UhdmAst::process_stream_op()  {
	// Create a for loop that does what a streaming operator would do
	auto block_node = find_ancestor({AST::AST_BLOCK, AST::AST_ALWAYS, AST::AST_INITIAL});
	auto process_node = find_ancestor({AST::AST_ALWAYS, AST::AST_INITIAL});
	auto module_node = find_ancestor({AST::AST_MODULE, AST::AST_FUNCTION, AST::AST_PACKAGE});
	log_assert(module_node);
	if (!process_node) {
		if (module_node->type != AST::AST_FUNCTION) {
			// Create a @* always block
			process_node = make_ast_node(AST::AST_ALWAYS);
			module_node->children.push_back(process_node);
			block_node = make_ast_node(AST::AST_BLOCK);
			process_node->children.push_back(block_node);
		} else {
			// Create only block
			block_node = make_ast_node(AST::AST_BLOCK);
			module_node->children.push_back(block_node);
		}
	}

	auto loop_id = shared.next_loop_id();
	auto loop_counter = make_ast_node(AST::AST_WIRE,
									  {make_ast_node(AST::AST_RANGE,
													 {AST::AstNode::mkconst_int(31, false),
													  AST::AstNode::mkconst_int(0, false)})});
	loop_counter->is_reg = true;
	loop_counter->is_signed = true;
	loop_counter->str = "\\loop" + std::to_string(loop_id) + "::i";
	module_node->children.insert(module_node->children.end() - 1, loop_counter);
	auto loop_counter_ident = make_ast_node(AST::AST_IDENTIFIER);
	loop_counter_ident->str = loop_counter->str;

	auto lhs_node = find_ancestor({AST::AST_ASSIGN, AST::AST_ASSIGN_EQ, AST::AST_ASSIGN_LE})->children[0];
	// Temp var to allow concatenation
	AST::AstNode *temp_var = nullptr;
	AST::AstNode *bits_call = nullptr;
	if (lhs_node->type == AST::AST_WIRE) {
		module_node->children.insert(module_node->children.begin(), lhs_node->clone());
		temp_var = lhs_node->clone(); //if we already have wire as lhs, we want to create the same wire for temp_var 
		lhs_node->children.clear();
		lhs_node->type = AST::AST_IDENTIFIER;
		bits_call = make_ast_node(AST::AST_FCALL, {lhs_node->clone()});
		bits_call->str = "\\$bits";
	} else {
		// otherwise, we need to calculate size using bits fcall
		bits_call = make_ast_node(AST::AST_FCALL, {lhs_node->clone()});
		bits_call->str = "\\$bits";
		temp_var = make_ast_node(AST::AST_WIRE,
									  {make_ast_node(AST::AST_RANGE,
													 {make_ast_node(AST::AST_SUB,
																	{bits_call,
																	 AST::AstNode::mkconst_int(1, false)}),
													  AST::AstNode::mkconst_int(0, false)})});
	}

	temp_var->str = "\\loop" + std::to_string(loop_id) + "::temp";
	module_node->children.insert(module_node->children.end() - 1, temp_var);
	auto temp_var_ident = make_ast_node(AST::AST_IDENTIFIER);
	temp_var_ident->str = temp_var->str;
	auto temp_assign = make_ast_node(AST::AST_ASSIGN_EQ, {temp_var_ident});
	block_node->children.push_back(temp_assign);

	// Assignment in the loop's block
	auto assign_node = make_ast_node(AST::AST_ASSIGN_EQ, {lhs_node->clone(), temp_var_ident->clone()});
	AST::AstNode* slice_size = nullptr; // First argument in streaming op
	visit_one_to_many({vpiOperand},
					  obj_h,
					  [&](AST::AstNode* node) {
						  if (!slice_size && node->type == AST::AST_CONSTANT) {
							  slice_size = node;
						  } else {
							  temp_assign->children.push_back(node);
						  }
						});
	if (!slice_size) {
		slice_size = AST::AstNode::mkconst_int(1, true);
	}

	// Initialization of the loop counter to 0
	auto init_stmt = make_ast_node(AST::AST_ASSIGN_EQ,
								   {loop_counter_ident, AST::AstNode::mkconst_int(0, true)});

	// Loop condition (loop counter < $bits(RHS))
	auto cond_stmt = make_ast_node(AST::AST_LE,
								   {loop_counter_ident->clone(),
									make_ast_node(AST::AST_SUB,
												  {bits_call->clone(), slice_size->clone()})});

	// Increment loop counter
	auto inc_stmt = make_ast_node(AST::AST_ASSIGN_EQ,
								  {loop_counter_ident->clone(),
								   make_ast_node(AST::AST_ADD,
												 {loop_counter_ident->clone(), slice_size})});

	// Range on the LHS of the assignment
	auto lhs_range = make_ast_node(AST::AST_RANGE);
	auto lhs_selfsz = make_ast_node(AST::AST_SELFSZ,
									{make_ast_node(AST::AST_SUB,
												   {make_ast_node(AST::AST_SUB,
																  {bits_call->clone(), AST::AstNode::mkconst_int(1, true)}),
													loop_counter_ident->clone()})});
	lhs_range->children.push_back(make_ast_node(AST::AST_ADD,
												{lhs_selfsz, AST::AstNode::mkconst_int(0, true)}));
	lhs_range->children.push_back(make_ast_node(AST::AST_SUB,
												{make_ast_node(AST::AST_ADD,
															   {lhs_selfsz->clone(), AST::AstNode::mkconst_int(1, true)}),
												 slice_size->clone()}));

	// Range on the RHS of the assignment
	auto rhs_range = make_ast_node(AST::AST_RANGE);
	auto rhs_selfsz = make_ast_node(AST::AST_SELFSZ,
									{loop_counter_ident->clone()});
	rhs_range->children.push_back(make_ast_node(AST::AST_SUB,
												{make_ast_node(AST::AST_ADD,
															   {rhs_selfsz, slice_size->clone()}),
												 AST::AstNode::mkconst_int(1, true)}));
	rhs_range->children.push_back(make_ast_node(AST::AST_ADD,
												{rhs_selfsz->clone(), AST::AstNode::mkconst_int(0, true)}));

	// Put ranges on the sides of the assignment
	assign_node->children[0]->children.push_back(lhs_range);
	assign_node->children[1]->children.push_back(rhs_range);

	// Putting the loop together
	auto loop_node = make_ast_node(AST::AST_FOR);
	loop_node->str = "$loop" + std::to_string(loop_id);
	loop_node->children.push_back(init_stmt);
	loop_node->children.push_back(cond_stmt);
	loop_node->children.push_back(inc_stmt);
	loop_node->children.push_back(new AST::AstNode(AST::AST_BLOCK, assign_node));

	block_node->children.push_back(new AST::AstNode(AST::AST_BLOCK, loop_node));
	// Yosys requires that AST_BLOCK str was set
	block_node->children[1]->str = "\\stream_op_block" + std::to_string(loop_id);
	block_node->children[1]->children[0]->children[3]->str = "\\stream_op_block" + std::to_string(loop_id);

	// Do not create a node
	shared.report.mark_handled(obj_h);
}

void UhdmAst::process_list_op() {
	// Add all operands as children of process node
	if (auto parent_node = find_ancestor({AST::AST_ALWAYS, AST::AST_COND})) {
		visit_one_to_many({vpiOperand},
						  obj_h,
						  [&](AST::AstNode* node) {
							  // add directly to process/cond node
							  if (node) {
								  parent_node->children.push_back(node);
							  }
						  });
	}
	// Do not create a node
	shared.report.mark_handled(obj_h);
}

void UhdmAst::process_cast_op() {
	current_node = make_ast_node(AST::AST_NONE);
	visit_one_to_many({vpiOperand},
					  obj_h,
					  [&](AST::AstNode* node) {
						  node->cloneInto(current_node);
					  });
	vpiHandle typespec_h = vpi_handle(vpiTypespec, obj_h);
	shared.report.mark_handled(typespec_h);
	vpi_free_object(typespec_h);
}

void UhdmAst::process_inside_op() {
	current_node = make_ast_node(AST::AST_EQ);
	AST::AstNode* lhs = nullptr;
	visit_one_to_many({vpiOperand},
						obj_h,
						[&](AST::AstNode* node) {
							if (!lhs) {
								lhs = node;
							}
							if (current_node->children.size() < 2) {
								current_node->children.push_back(node);
							} else {
								auto or_node = new AST::AstNode(AST::AST_LOGIC_OR);
								or_node->filename = current_node->filename;
								or_node->location = current_node->location;
								auto eq_node = new AST::AstNode(AST::AST_EQ);
								eq_node->filename = current_node->filename;
								eq_node->location = current_node->location;
								or_node->children.push_back(current_node);
								or_node->children.push_back(eq_node);
								eq_node->children.push_back(lhs->clone());
								eq_node->children.push_back(node);
								current_node = or_node;
							}
						});
}

void UhdmAst::process_assignment_pattern_op() {
	current_node = make_ast_node(AST::AST_CONCAT);
	if (auto param_node = find_ancestor({AST::AST_PARAMETER, AST::AST_LOCALPARAM})) {
		std::map<size_t, AST::AstNode*> ordered_children;
		visit_one_to_many({vpiOperand},
						  obj_h,
						  [&](AST::AstNode* node) {
							  if (node->type == AST::AST_ASSIGN || node->type == AST::AST_ASSIGN_EQ || node->type == AST::AST_ASSIGN_LE) {
								  // Find at what position in the concat should we place this node
								  auto key = node->children[0]->str;
								  key = key.substr(key.find('.') + 1);
								  auto param_type = shared.param_types[param_node->str];
								  size_t pos = std::find_if(param_type->children.begin(), param_type->children.end(),
															[key](AST::AstNode* child) { return child->str == key; })
									  - param_type->children.begin();
								  ordered_children.insert(std::make_pair(pos, node->children[1]->clone()));
							  } else {
								  current_node->children.push_back(node);
							  }
						  });
		for (auto p : ordered_children) {
			current_node->children.push_back(p.second);
		}
		return;
	}
	auto assign_node = find_ancestor({AST::AST_ASSIGN, AST::AST_ASSIGN_EQ, AST::AST_ASSIGN_LE});

	auto proc_node = find_ancestor({AST::AST_BLOCK, AST::AST_ALWAYS, AST::AST_INITIAL, AST::AST_MODULE, AST::AST_PACKAGE, AST::AST_CELL});
	if (proc_node && proc_node->type == AST::AST_CELL && shared.top_nodes.count(proc_node->children[0]->str)) {
		proc_node = shared.top_nodes[proc_node->children[0]->str];
	}
	std::vector<AST::AstNode*> assignments;
	visit_one_to_many({vpiOperand},
					  obj_h,
					  [&](AST::AstNode* node) {
						  if (node->type == AST::AST_ASSIGN || node->type == AST::AST_ASSIGN_EQ || node->type == AST::AST_ASSIGN_LE) {
							  assignments.push_back(node);
						  } else {
							  current_node->children.push_back(node);
						  }
					  });
	std::reverse(current_node->children.begin(), current_node->children.end());
	if (!assignments.empty()) {
		if (current_node->children.empty()) {
			assign_node->children[0] = assignments[0]->children[0];
			current_node = assignments[0]->children[1];
			assignments[0]->children.clear();
			delete assignments[0];
			proc_node->children.insert(proc_node->children.end(), assignments.begin() + 1, assignments.end());
		} else {
			proc_node->children.insert(proc_node->children.end(), assignments.begin(), assignments.end());
		}
	}
}

void UhdmAst::process_tagged_pattern() {
	auto assign_node = find_ancestor({AST::AST_ASSIGN, AST::AST_ASSIGN_EQ, AST::AST_ASSIGN_LE});
	auto assign_type = AST::AST_ASSIGN;
	AST::AstNode* lhs_node = nullptr;
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
	vpi_free_object(typespec_h);
	visit_one_to_one({vpiPattern},
					 obj_h,
					 [&](AST::AstNode* node) {
						 current_node->children.push_back(node);
					 });
}

void UhdmAst::process_bit_select() {
	current_node = make_ast_node(AST::AST_IDENTIFIER);
	visit_one_to_one({vpiIndex},
					 obj_h,
					 [&](AST::AstNode* node) {
						 auto range_node = new AST::AstNode(AST::AST_RANGE, node);
						 range_node->filename = current_node->filename;
						 range_node->location = current_node->location;
						 current_node->children.push_back(range_node);
					 });
}

void UhdmAst::process_part_select() {
	current_node = make_ast_node(AST::AST_IDENTIFIER);
	visit_one_to_one({vpiParent},
					 obj_h,
					 [&](AST::AstNode* node) {
						 current_node->str = node->str;
					 });
	auto range_node = new AST::AstNode(AST::AST_RANGE);
	range_node->filename = current_node->filename;
	range_node->location = current_node->location;
	visit_one_to_one({vpiLeftRange,
					  vpiRightRange},
					 obj_h,
					 [&](AST::AstNode* node) {
						 range_node->children.push_back(node);
					 });
	current_node->children.push_back(range_node);
}

void UhdmAst::process_indexed_part_select() {
	current_node = make_ast_node(AST::AST_IDENTIFIER);
	visit_one_to_one({vpiParent},
					 obj_h,
					 [&](AST::AstNode* node) {
						 current_node->str = node->str;
					 });
	//TODO: check if there are other types, for now only handle 1 and 2 (+: and -:)
	auto indexed_part_select_type = vpi_get(vpiIndexedPartSelectType, obj_h) == 1 ? AST::AST_ADD : AST::AST_SUB;
	auto range_node = new AST::AstNode(AST::AST_RANGE);
	range_node->filename = current_node->filename;
	range_node->location = current_node->location;
	visit_one_to_one({vpiBaseExpr},
					 obj_h,
					 [&](AST::AstNode* node) {
						 range_node->children.push_back(node);
					 });
	visit_one_to_one({vpiWidthExpr},
					 obj_h,
					 [&](AST::AstNode* node) {
						 auto right_range_node = new AST::AstNode(indexed_part_select_type);
						 right_range_node->children.push_back(range_node->children[0]->clone());
						 right_range_node->children.push_back(node);
						 auto sub = new AST::AstNode(indexed_part_select_type == AST::AST_ADD ? AST::AST_SUB : AST::AST_ADD);
						 sub->children.push_back(right_range_node);
						 sub->children.push_back(AST::AstNode::mkconst_int(1, false, 1));
						 range_node->children.push_back(sub);
						 //range_node->children.push_back(right_range_node);
					 });
	if (indexed_part_select_type == AST::AST_ADD) {
		std::reverse(range_node->children.begin(), range_node->children.end());
	}
	current_node->children.push_back(range_node);
}

void UhdmAst::process_var_select() {
	current_node = make_ast_node(AST::AST_IDENTIFIER);
	visit_one_to_many({vpiIndex},
					  obj_h,
					  [&](AST::AstNode* node) {
						  if (node->str == current_node->str) {
							  for (auto child : node->children) {
								  current_node->children.push_back(child->clone());
							  }
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

void UhdmAst::process_if_else() {
	current_node = make_ast_node(AST::AST_CASE);
	visit_one_to_one({vpiCondition},
					 obj_h,
					 [&](AST::AstNode* node) {
						 auto reduce_node = new AST::AstNode(AST::AST_REDUCE_BOOL, node);
						 current_node->children.push_back(reduce_node);
					 });
	// If true:
	auto *condition = new AST::AstNode(AST::AST_COND);
	auto *constant = AST::AstNode::mkconst_int(1, false, 1);
	condition->children.push_back(constant);
	visit_one_to_one({vpiStmt},
					 obj_h,
					 [&](AST::AstNode* node) {
						 auto *statements = new AST::AstNode(AST::AST_BLOCK);
						 statements->children.push_back(node);
						 condition->children.push_back(statements);
					 });
	current_node->children.push_back(condition);
	// Else:
	if (vpi_get(vpiType, obj_h) == vpiIfElse) {
		auto *condition = new AST::AstNode(AST::AST_COND);
		auto *elseBlock = new AST::AstNode(AST::AST_DEFAULT);
		condition->children.push_back(elseBlock);
		visit_one_to_one({vpiElseStmt},
						 obj_h,
						 [&](AST::AstNode* node) {
							 auto *statements = new AST::AstNode(AST::AST_BLOCK);
							 statements->children.push_back(node);
							 condition->children.push_back(statements);
						 });
		current_node->children.push_back(condition);
	}
}

void UhdmAst::process_for() {
	current_node = make_ast_node(AST::AST_FOR);
	auto loop_id = shared.next_loop_id();
	current_node->str = "$loop" + std::to_string(loop_id);
	auto loop_parent_node = make_ast_node(AST::AST_BLOCK);
	loop_parent_node->str = current_node->str;
	visit_one_to_many({vpiForInitStmt},
					  obj_h,
					  [&](AST::AstNode* node) {
						  if (node->type == AST::AST_ASSIGN_LE) node->type = AST::AST_ASSIGN_EQ;
						  if (node->children[0]->type == AST::AST_WIRE) {
						  	auto *wire = node->children[0]->clone();
							wire->is_reg = true;
							loop_parent_node->children.push_back(wire);
							node->children[0]->type = AST::AST_IDENTIFIER;
							node->children[0]->is_signed = false;
							node->children[0]->children.clear();
						  }
						  current_node->children.push_back(node);
					  });
	visit_one_to_one({vpiCondition},
					 obj_h,
					 [&](AST::AstNode* node) {
						 current_node->children.push_back(node);
					 });
	visit_one_to_many({vpiForIncStmt},
					  obj_h,
					  [&](AST::AstNode* node) {
						  if (node->type == AST::AST_ASSIGN_LE) node->type = AST::AST_ASSIGN_EQ;
						  current_node->children.push_back(node);
					  });
	visit_one_to_one({vpiStmt},
					 obj_h,
					 [&](AST::AstNode* node) {
						 auto *statements = make_ast_node(AST::AST_BLOCK);
						 statements->children.push_back(node);
						 current_node->children.push_back(statements);
					 });
	//auto for_block = make_ast_node(AST::AST_BLOCK);
	//for_block->str = "";
	//for_block->children.push_back(current_node);
	loop_parent_node->children.push_back(current_node);
	current_node = loop_parent_node;
}

void UhdmAst::process_gen_scope_array() {
	current_node = make_ast_node(AST::AST_GENBLOCK);
	visit_one_to_many({vpiGenScope},
					  obj_h,
					  [&](AST::AstNode* genscope_node) {
						  for (auto* child : genscope_node->children) {
							  if (child->type == AST::AST_PARAMETER ||
									  child->type == AST::AST_LOCALPARAM) {
							  	  auto param_str = child->str.substr(1);
							  	  auto array_str = "[" + param_str + "]";
								  genscope_node->visitEachDescendant([&](AST::AstNode* node) {
									  auto pos = node->str.find(array_str);
									  if (pos != std::string::npos) {
									  	node->type = AST::AST_PREFIX;
										auto *param = new AST::AstNode(AST::AST_IDENTIFIER);
										param->str = child->str;
										auto *field = new AST::AstNode(AST::AST_IDENTIFIER);
										field->str = "\\" + node->str.substr(node->str.rfind("]") + 2);
										node->str = node->str.substr(0, node->str.find("["));
										node->children.push_back(param);
										node->children.push_back(field);
									  }
								  });
							  }
						  }
						  current_node->children.insert(current_node->children.end(),
														genscope_node->children.begin(),
														genscope_node->children.end());
					  });
}

void UhdmAst::process_gen_scope() {
	current_node = make_ast_node(AST::AST_GENBLOCK);
	visit_one_to_many({
					   vpiParamAssign,
					   vpiParameter,
					   vpiNet,
					   vpiArrayNet,
					   vpiVariables,
					   vpiContAssign,
					   vpiProcess,
					   vpiModule,
					   vpiGenScopeArray},
					   obj_h,
					   [&](AST::AstNode* node) {
						   if (node) {
						   	   if ((node->type == AST::AST_PARAMETER || node->type == AST::AST_LOCALPARAM) &&
									   node->children.size() == 0) {

							   	return; //skip parameters without any children
							   }
							   current_node->children.push_back(node);
						   }
					   });
}

void UhdmAst::process_case() {
	current_node = make_ast_node(AST::AST_CASE);
	visit_one_to_one({vpiCondition},
					 obj_h,
					 [&](AST::AstNode* node) {
						 current_node->children.push_back(node);
					 });
	visit_one_to_many({vpiCaseItem},
					  obj_h,
					  [&](AST::AstNode* node) {
						  current_node->children.push_back(node);
					  });
}

void UhdmAst::process_case_item() {
	current_node = make_ast_node(AST::AST_COND);
	visit_one_to_many({vpiExpr},
					  obj_h,
					  [&](AST::AstNode* node) {
						  if (node) {
							  current_node->children.push_back(node);
						  }
					  });
	if (current_node->children.empty()) {
		current_node->children.push_back(new AST::AstNode(AST::AST_DEFAULT));
	}
	visit_one_to_one({vpiStmt},
					 obj_h,
					 [&](AST::AstNode* node) {
						 if (node->type != AST::AST_BLOCK) {
							 auto block_node = new AST::AstNode(AST::AST_BLOCK);
							 block_node->children.push_back(node);
							 node = block_node;
						 }
						 current_node->children.push_back(node);
					 });
}

void UhdmAst::process_range() {
	current_node = make_ast_node(AST::AST_RANGE);
	visit_one_to_one({vpiLeftRange,
					  vpiRightRange},
					 obj_h,
					 [&](AST::AstNode* node) {
						 current_node->children.push_back(node);
					 });
}

void UhdmAst::process_return() {
	current_node = make_ast_node(AST::AST_ASSIGN_EQ);
	auto func_node = find_ancestor({AST::AST_FUNCTION, AST::AST_TASK});
	if (!func_node->children.empty()) {
		auto lhs = new AST::AstNode(AST::AST_IDENTIFIER);
		lhs->str = func_node->children[0]->str;
		current_node->children.push_back(lhs);
	}
	visit_one_to_one({vpiCondition},
					 obj_h,
					 [&](AST::AstNode* node) {
						 current_node->children.push_back(node);
					 });
}

void UhdmAst::process_function() {
	current_node = make_ast_node(vpi_get(vpiType, obj_h) == vpiFunction ? AST::AST_FUNCTION : AST::AST_TASK);
	visit_one_to_one({vpiReturn},
					 obj_h,
					 [&](AST::AstNode* node) {
						 if (node) {
							 current_node->children.push_back(node);
							 node->str = "$result";
						 }
					 });
	visit_one_to_many({vpiIODecl},
					  obj_h,
					  [&](AST::AstNode* node) {
						  node->type = AST::AST_WIRE;
						  current_node->children.push_back(node);
					  });
	visit_one_to_many({vpiVariables},
					  obj_h,
					  [&](AST::AstNode* node) {
						  current_node->children.push_back(node);
					  });
	visit_one_to_one({vpiStmt},
					 obj_h,
					 [&](AST::AstNode* node) {
						 if (node) {
							 current_node->children.push_back(node);
						 }
					 });
}

void UhdmAst::process_logic_var() {
	current_node = make_ast_node(AST::AST_WIRE);
	//TODO: add const attribute, but it seems it is little more
	//then just setting boolean value
	//current_node->is_const = vpi_get(vpiConstantVariable, obj_h);
	visit_one_to_one({vpiTypespec},
					 obj_h,
					 [&](AST::AstNode* node) {
					 	 if (node) {
							 auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
							 wiretype_node->str = node->str;
							 // wiretype needs to be 1st node (if port have also another range nodes)
							 current_node->children.insert(current_node->children.begin(), wiretype_node);
							 current_node->is_custom_type=true;
						 }
					 });
	visit_range(obj_h,
				[&](AST::AstNode* node) {
					current_node->children.push_back(node);
				});
	visit_default_expr(obj_h);
}

void UhdmAst::process_sys_func_call() {
	current_node = make_ast_node(AST::AST_FCALL);
	if (current_node->str == "\\$signed") {
		current_node->type = AST::AST_TO_SIGNED;
	} else if (current_node->str == "\\$unsigned") {
		current_node->type = AST::AST_TO_UNSIGNED;
	} else if (current_node->str == "\\$display" || current_node->str == "\\$time") {
		current_node->type = AST::AST_TCALL;
		current_node->str = current_node->str.substr(1);
	} else if (current_node->str == "\\$readmemh") {
		current_node->type = AST::AST_TCALL;
	}

	visit_one_to_many({vpiArgument},
					  obj_h,
					  [&](AST::AstNode* node) {
						  if (node) {
							  current_node->children.push_back(node);
						  }
					  });
}

void UhdmAst::process_func_call() {
	current_node = make_ast_node(AST::AST_FCALL);
	visit_one_to_many({vpiArgument},
					  obj_h,
					  [&](AST::AstNode* node) {
						  if (node) {
						  	  if (node->type == AST::AST_PARAMETER ||
									  node->type == AST::AST_LOCALPARAM) {
							  	node->type = AST::AST_IDENTIFIER;
							  }
							  current_node->children.push_back(node);
						  }
					  });
}

void UhdmAst::process_immediate_assert() {
	current_node = make_ast_node(AST::AST_ASSERT);
	visit_one_to_one({vpiExpr},
					 obj_h,
					 [&](AST::AstNode* n) {
						 if (n) {
							 current_node->children.push_back(n);
						 }
					 });
}

void UhdmAst::process_hier_path() {
	current_node = make_ast_node(AST::AST_IDENTIFIER);
	current_node->str = "\\";
	visit_one_to_many({vpiActual},
					  obj_h,
					  [&](AST::AstNode* node) {
						  if (current_node->str == "\\" && node->children.size() > 0 && node->children[0]->type == AST::AST_RANGE) {
						  	current_node->type = AST::AST_PREFIX;
							current_node->str = node->str;
							current_node->children.push_back(node->children[0]->children[0]->clone());
						  } else {
						  	if (current_node->type == AST::AST_IDENTIFIER) {
								if (current_node->str != "\\") {
								      current_node->str += ".";
								}
								current_node->str += node->str.substr(1);
								current_node->children = node->children;
							} else {
								current_node->children.push_back(node->clone());
							}
						  }
					  });
}

void UhdmAst::process_logic_typespec() {
	current_node = make_ast_node(AST::AST_WIRE);
	current_node->is_logic = true;
	visit_range(obj_h,
				[&](AST::AstNode* node) {
					if (node) {
						current_node->children.push_back(node);
					}
				});
	if (current_node->str != "") {
		add_typedef(find_ancestor({AST::AST_MODULE, AST::AST_PACKAGE}), current_node);
	}
}

void UhdmAst::process_int_typespec() {
	current_node = make_ast_node(AST::AST_WIRE);
	auto left_const = AST::AstNode::mkconst_int(31, true);
	auto right_const = AST::AstNode::mkconst_int(0, true);
	auto range = new AST::AstNode(AST::AST_RANGE, left_const, right_const);
	current_node->children.push_back(range);
	current_node->is_signed = true;
	if (current_node->str != "") {
		add_typedef(find_ancestor({AST::AST_MODULE, AST::AST_PACKAGE}), current_node);
	}
}

void UhdmAst::process_bit_typespec() {
	current_node = make_ast_node(AST::AST_WIRE);
	visit_range(obj_h,
				[&](AST::AstNode* node) {
					if (node) {
						current_node->children.push_back(node);
					}
				});
	if (current_node->str != "") {
		add_typedef(find_ancestor({AST::AST_MODULE, AST::AST_PACKAGE}), current_node);
	}
}

AST::AstNode* UhdmAst::process_object(vpiHandle obj_handle) {
	obj_h = obj_handle;
	const unsigned object_type = vpi_get(vpiType, obj_h);
	const uhdm_handle* const handle = (const uhdm_handle*) obj_h;
	const UHDM::BaseClass* const object = (const UHDM::BaseClass*) handle->object;

	if (shared.debug_flag) {
		std::cout << indent << "Object '" << object->VpiName() << "' of type '" << UHDM::VpiTypeName(obj_h) << '\'' << std::endl;
	}

	if (shared.visited.find(object) != shared.visited.end()) {
		return shared.visited[object]->clone();
	}
	switch(object_type) {
		case vpiDesign: process_design(); break;
		case vpiParameter: process_parameter(); break;
		case vpiPort: process_port(); break;
		case vpiModule: process_module(); break;
		case vpiStructTypespec: process_struct_typespec(); break;
		case vpiPackedArrayTypespec: process_packed_array_typespec(); break;
		case vpiTypespecMember: process_typespec_member(); break;
		case vpiEnumTypespec: process_enum_typespec(); break;
		case vpiEnumConst: process_enum_const(); break;
		case vpiEnumVar:
		case vpiEnumNet:
		case vpiStructVar:
		case vpiStructNet: process_custom_var(); break;
		case vpiIntVar: process_int_var(); break;
		case vpiRealVar: process_real_var(); break;
		case vpiPackedArrayVar:
		case vpiArrayVar: process_array_var(); break;
		case vpiParamAssign: process_param_assign(); break;
		case vpiContAssign: process_cont_assign(); break;
		case vpiAssignStmt:
		case vpiAssignment: process_assignment(); break;
		case vpiRefObj: current_node = make_ast_node(AST::AST_IDENTIFIER); break;
		case vpiNet: process_net(); break;
		case vpiArrayNet: process_array_net(); break;
		case vpiPackedArrayNet: process_packed_array_net(); break;
		case vpiPackage: process_package(); break;
		case vpiInterface: process_interface(); break;
		case vpiModport: process_modport(); break;
		case vpiIODecl: process_io_decl(); break;
		case vpiAlways: process_always(); break;
		case vpiEventControl: process_event_control(); break;
		case vpiInitial: process_initial(); break;
		case vpiNamedBegin:
		case vpiBegin: process_begin(); break;
		case vpiCondition:
		case vpiOperation: process_operation(); break;
		case vpiTaggedPattern: process_tagged_pattern(); break;
		case vpiBitSelect: process_bit_select(); break;
		case vpiPartSelect: process_part_select(); break;
		case vpiIndexedPartSelect: process_indexed_part_select(); break;
		case vpiVarSelect: process_var_select(); break;
		case vpiIf:
		case vpiIfElse: process_if_else(); break;
		case vpiFor: process_for(); break;
		case vpiGenScopeArray: process_gen_scope_array(); break;
		case vpiGenScope: process_gen_scope(); break;
		case vpiCase: process_case(); break;
		case vpiCaseItem: process_case_item(); break;
		case vpiConstant: current_node = process_value(obj_h); break;
		case vpiRange: process_range(); break;
		case vpiReturn: process_return(); break;
		case vpiFunction:
		case vpiTask: process_function(); break;
		case vpiBitVar:
		case vpiLogicVar: process_logic_var(); break;
		case vpiSysFuncCall: process_sys_func_call(); break;
		case vpiFuncCall: process_func_call(); break;
		case vpiTaskCall: current_node = make_ast_node(AST::AST_TCALL); break;
		case vpiImmediateAssert:
				  if (!shared.no_assert)
					  process_immediate_assert();
				  break;
		case vpiHierPath: process_hier_path(); break;
		case UHDM::uhdmimport: break;
		case vpiLogicTypespec: process_logic_typespec(); break;
		case vpiIntTypespec: process_int_typespec(); break;
		case vpiBitTypespec: process_bit_typespec(); break;
		case vpiProgram:
		default: report_error("Encountered unhandled object '%s' of type '%s' at %s:%d\n", object->VpiName().c_str(),
							  UHDM::VpiTypeName(obj_h).c_str(), object->VpiFile().c_str(), object->VpiLineNo()); break;
	}

	// Check if we initialized the node in switch-case
	if (current_node) {
		if (current_node->type != AST::AST_NONE) {
			shared.report.mark_handled(object);
			return current_node;
		}
		shared.visited.erase(object);
	}
	return nullptr;
}

AST::AstNode* UhdmAst::visit_designs(const std::vector<vpiHandle>& designs) {
	current_node = new AST::AstNode(AST::AST_DESIGN);
	for (auto design : designs) {
		UhdmAst ast(this, shared, indent);
		auto *nodes = ast.process_object(design);
		// Flatten multiple designs into one
		for (auto child : nodes->children) {
			current_node->children.push_back(child);
		}
	}
	return current_node;
}

void UhdmAst::report_error(const char *format, ...) const {
	va_list args;
	va_start(args, format);
	if (shared.stop_on_error) {
		logv_error(format, args);
	} else {
		logv_warning(format, args);
	}
}

YOSYS_NAMESPACE_END

