#ifndef _UHDM_AST_SHARED_H_
#define _UHDM_AST_SHARED_H_ 1

#include "uhdmastreport.h"
#include <string>
#include <unordered_map>

YOSYS_NAMESPACE_BEGIN

class UhdmAstShared
{
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

    // Flag that determines whether we should only parse the design
    // applies only to read_systemverilog command
    bool parse_only = false;

    // Top nodes of the design (modules, interfaces)
    std::unordered_map<std::string, AST::AstNode *> top_nodes;

    // UHDM node coverage report
    UhdmAstReport report;

    // Map from AST param nodes to their types (used for params with struct types)
    std::unordered_map<std::string, AST::AstNode *> param_types;

    AST::AstNode *current_top_node = nullptr;
};

YOSYS_NAMESPACE_END

#endif
