/*
 * Copyright 2020-2022 F4PGA Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
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
    log("    -parse-only\n");
    log("        this parameter only applies to read_systemverilog command,\n");
    log("        it runs only Surelog to parse design, but doesn't load generated\n");
    log("        tree into Yosys.\n");
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
    std::vector<std::string> unhandled_args;

    for (size_t i = 0; i < args.size(); i++) {
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
        } else if (args[i] == "-parse-only") {
            this->shared.parse_only = true;
        } else {
            unhandled_args.push_back(args[i]);
        }
    }
    extra_args(f, filename, args, args.size() - 1);
    // pass only unhandled args to Surelog
    // unhandled args starts with command name,
    // but Surelog expects args[0] to be program name
    // and skips it
    this->args = unhandled_args;

    AST::current_filename = filename;
    AST::set_line_num = &set_line_num;
    AST::get_line_num = &get_line_num;

    bool dont_redefine = false;
    bool default_nettype_wire = true;

    AST::AstNode *current_ast = parse(filename);

    if (current_ast) {
        AST::process(design, current_ast, dump_ast1, dump_ast2, no_dump_ptr, dump_vlog1, dump_vlog2, dump_rtlil, false, false, false, false, false,
                     false, false, false, false, false, dont_redefine, false, defer, default_nettype_wire);
        delete current_ast;
    }
}

YOSYS_NAMESPACE_END
