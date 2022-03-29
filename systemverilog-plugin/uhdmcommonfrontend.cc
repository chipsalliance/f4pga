/*
 * Copyright (C) 2019-2022 The SymbiFlow Authors
 *
 * Use of this source code is governed by a ISC-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/ISC
 *
 * SPDX-License-Identifier: ISC
 *
 */

#include "uhdmcommonfrontend.h"

YOSYS_NAMESPACE_BEGIN

/* Stub for AST::process */
static void set_line_num(int) {}

/* Stub for AST::process */
static int get_line_num(void) { return 1; }

void UhdmCommonFrontend::print_read_options()
{
    log("    -noassert\n");
    log("        ignore assert() statements");
    log("\n");
    log("    -debug\n");
    log("        alias for -dump_ast1 -dump_ast2 -dump_vlog1 -dump_vlog2 -yydebug\n");
    log("\n");
    log("    -dump_ast1\n");
    log("        dump abstract syntax tree (before simplification)\n");
    log("\n");
    log("    -dump_ast2\n");
    log("        dump abstract syntax tree (after simplification)\n");
    log("\n");
    log("    -no_dump_ptr\n");
    log("        do not include hex memory addresses in dump (easier to diff dumps)\n");
    log("\n");
    log("    -dump_vlog1\n");
    log("        dump ast as Verilog code (before simplification)\n");
    log("\n");
    log("    -dump_vlog2\n");
    log("        dump ast as Verilog code (after simplification)\n");
    log("\n");
    log("    -dump_rtlil\n");
    log("        dump generated RTLIL netlist\n");
    log("\n");
    log("    -yydebug\n");
    log("        enable parser debug output\n");
    log("\n");
    log("    -report [directory]\n");
    log("        write a coverage report for the UHDM file\n");
    log("\n");
    log("    -defer\n");
    log("        only read the abstract syntax tree and defer actual compilation\n");
    log("        to a later 'hierarchy' command. Useful in cases where the default\n");
    log("        parameters of modules yield invalid or not synthesizable code.\n");
    log("\n");
}

void UhdmCommonFrontend::execute(std::istream *&f, std::string filename, std::vector<std::string> args, RTLIL::Design *design)
{
    this->call_log_header(design);
    this->args = args;

    bool defer = false;
    bool dump_ast1 = false;
    bool dump_ast2 = false;
    bool dump_vlog1 = false;
    bool dump_vlog2 = false;
    bool no_dump_ptr = false;
    bool dump_rtlil = false;

    for (size_t i = 1; i < args.size(); i++) {
        if (args[i] == "-debug") {
            dump_ast1 = true;
            dump_ast2 = true;
            dump_vlog1 = true;
            dump_vlog2 = true;
            this->shared.debug_flag = true;
        } else if (args[i] == "-report" && ++i < args.size()) {
            this->report_directory = args[i];
            this->shared.stop_on_error = false;
        } else if (args[i] == "-noassert") {
            this->shared.no_assert = true;
        } else if (args[i] == "-defer") {
            defer = true;
        } else if (args[i] == "-dump_ast1") {
            dump_ast1 = true;
        } else if (args[i] == "-dump_ast2") {
            dump_ast2 = true;
        } else if (args[i] == "-dump_vlog1") {
            dump_vlog1 = true;
        } else if (args[i] == "-dump_vlog2") {
            dump_vlog2 = true;
        } else if (args[i] == "-no_dump_ptr") {
            no_dump_ptr = true;
        } else if (args[i] == "-dump_rtlil") {
            dump_rtlil = true;
        } else if (args[i] == "-yydebug") {
            this->shared.debug_flag = true;
        }
    }
    extra_args(f, filename, args, args.size() - 1);

    AST::current_filename = filename;
    AST::set_line_num = &set_line_num;
    AST::get_line_num = &get_line_num;

    bool dont_redefine = false;
    bool default_nettype_wire = true;

    AST::AstNode *current_ast = parse(filename);

    AST::process(design, current_ast, dump_ast1, dump_ast2, no_dump_ptr, dump_vlog1, dump_vlog2, dump_rtlil, false, false, false, false, false, false,
                 false, false, false, false, dont_redefine, false, defer, default_nettype_wire);
    delete current_ast;
}

YOSYS_NAMESPACE_END
