#ifndef _UHDM_AST_SHARED_H_
#define _UHDM_AST_SHARED_H_ 1

#include <string>
#include <unordered_map>
#include "uhdmastreport.h"

YOSYS_NAMESPACE_BEGIN

class UhdmAstShared {
	private:
		// Used for generating enum names
		unsigned enum_count = 0;

		// Used for generating port IDS
		unsigned port_count = 0;

		// Used for generating loop names
		unsigned loop_count = 0;

	public:
		// Generate the next enum ID (starting with 0)
		unsigned next_enum_id() { return enum_count++; }

		// Generate the next port ID (starting with 1)
		unsigned next_port_id() { return ++port_count; }

		// Generate the next loop ID (starting with 0)
		unsigned next_loop_id() { return loop_count++; }

		// Flag that determines whether debug info should be printed
		bool debug_flag = false;

		// Flag that determines whether we should ignore assert() statements
		bool no_assert = false;

		// Flag that determines whether errors should be fatal
		bool stop_on_error = true;

		// Top nodes of the design (modules, interfaces)
		std::unordered_map<std::string, AST::AstNode*> top_nodes;

		// Templates for top nodes of the design (in case there are multiple
		// versions, e.g. for different parameters)
		std::unordered_map<std::string, AST::AstNode*> top_node_templates;

		// Map from already visited UHDM nodes to AST nodes
		std::unordered_map<const UHDM::BaseClass*, AST::AstNode*> visited;

		// UHDM node coverage report
		UhdmAstReport report;

		// Vector with name of typedef and name of scope it is declared in
		std::vector<std::pair<std::string, std::string>> type_names;

		// Map from AST param nodes to their types (used for params with struct types)
		std::unordered_map<std::string, AST::AstNode*> param_types;
};

YOSYS_NAMESPACE_END

#endif
