#ifndef _UHDM_AST_H_
#define _UHDM_AST_H_ 1

#include <vector>
#include "frontends/ast/ast.h"
#undef cover

#include "uhdm.h"
#include "uhdmastshared.h"

YOSYS_NAMESPACE_BEGIN

class UhdmAst {
	private:
		// Walks through one-to-many relationships from given parent
		// node through the VPI interface, visiting child nodes belonging to
		// ChildrenNodeTypes that are present in the given object.
		void visit_one_to_many(const std::vector<int> child_node_types,
				       vpiHandle parent_handle,
				       const std::function<void(AST::AstNode*)>& f);

		// Walks through one-to-one relationships from given parent
		// node through the VPI interface, visiting child nodes belonging to
		// ChildrenNodeTypes that are present in the given object.
		void visit_one_to_one(const std::vector<int> child_node_types,
				      vpiHandle parent_handle,
				      const std::function<void(AST::AstNode*)>& f);

		// Visit children of type vpiRange that belong to the given parent node.
		void visit_range(vpiHandle obj_h, const std::function<void(AST::AstNode*)> &f);

		// Visit the default expression assigned to a variable.
		void visit_default_expr(vpiHandle obj_h);

		// Create an AstNode of the specified type with metadata extracted from
		// the given vpiHandle.
		AST::AstNode* make_ast_node(AST::AstNodeType type,
					    std::vector<AST::AstNode*> children = {});

		// Makes the passed node a cell node of the specified type
		void make_cell(vpiHandle obj_h, AST::AstNode* node, AST::AstNode* type);

		// Adds a typedef node to the current node
		void add_typedef(AST::AstNode* current_node, AST::AstNode* type_node);

		// Go up the UhdmAst to find a parent node of the specified type
		AST::AstNode* find_ancestor(const std::unordered_set<AST::AstNodeType>& types);

		// Reports that something went wrong with reading the UHDM file
		void report_error(const char *format, ...) const;

		// Processes the value connected to the specified node
		AST::AstNode* process_value(vpiHandle obj_h);

		// The parent UhdmAst
		UhdmAst* parent;

		// Data shared between all UhdmAst objects
		UhdmAstShared& shared;

		// The current VPI/UHDM handle
		vpiHandle obj_h = 0;

		// The current Yosys AST node
		AST::AstNode* current_node = nullptr;

		// Indentation used for debug printing
		std::string indent;

		// Mapping of names that should be replaced to new names
		std::unordered_map<std::string, std::string> node_renames;

		// Functions that process specific types of nodes
		void process_design();
		void process_parameter();
		void process_port();
		void process_module();
		void process_struct_typespec();
		void process_packed_array_typespec();
		void process_typespec_member();
		void process_enum_typespec();
		void process_enum_const();
		void process_custom_var();
		void process_int_var();
		void process_real_var();
		void process_array_var();
		void process_param_assign();
		void process_cont_assign();
		void process_cont_assign_net();
		void process_cont_assign_var_init();
		void process_assignment();
		void process_net();
		void process_packed_array_net();
		void process_array_net();
		void process_package();
		void process_interface();
		void process_modport();
		void process_io_decl();
		void process_always();
		void process_event_control();
		void process_initial();
		void process_begin();
		void process_operation();
		void process_stream_op();
		void process_list_op();
		void process_cast_op();
		void process_inside_op();
		void process_assignment_pattern_op();
		void process_tagged_pattern();
		void process_bit_select();
		void process_part_select();
		void process_indexed_part_select();
		void process_var_select();
		void process_if_else();
		void process_for();
		void process_gen_scope_array();
		void process_gen_scope();
		void process_case();
		void process_case_item();
		void process_range();
		void process_return();
		void process_function();
		void process_logic_var();
		void process_sys_func_call();
		void process_func_call();
		void process_immediate_assert();
		void process_hier_path();
		void process_logic_typespec();
		void process_int_typespec();
		void process_bit_typespec();

		UhdmAst(UhdmAst* p, UhdmAstShared& s, const std::string& i) : parent(p), shared(s), indent(i) {
			if (parent) node_renames = parent->node_renames;
		}

	public:
		UhdmAst(UhdmAstShared& s, const std::string& i = "") : UhdmAst(nullptr, s, i) {}

		// Visits single VPI object and creates proper AST node
		AST::AstNode* process_object(vpiHandle obj_h);

		// Visits all VPI design objects and returns created ASTs
		AST::AstNode* visit_designs(const std::vector<vpiHandle>& designs);

};

YOSYS_NAMESPACE_END

#endif
