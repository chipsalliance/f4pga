/*
 *  yosys -- Yosys Open SYnthesis Suite
 *
 *  Copyright (C) 2020 Antmicro

 *  Based on frontends/json/jsonparse.cc
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

#include "uhdmcommonfrontend.h"

YOSYS_NAMESPACE_BEGIN

/* Stub for AST::process */
static void set_line_num(int) {}

/* Stub for AST::process */
static int get_line_num(void) { return 1; }

void UhdmCommonFrontend::help()
{
    //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
    log("\n");
    log("    read_uhdm [options] [filename]\n");
    log("\n");
    log("Load design from a UHDM file into the current design\n");
    log("\n");
    log("    -noassert\n");
    log("        ignore assert() statements");
    log("\n");
    log("    -debug\n");
    log("        print debug info to stdout");
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
    this->args = args;

    bool defer = false;
    std::string report_directory;
    for (size_t i = 1; i < args.size(); i++) {
        if (args[i] == "-debug") {
            this->shared.debug_flag = true;
        } else if (args[i] == "-report" && ++i < args.size()) {
            this->report_directory = args[i];
            this->shared.stop_on_error = false;
        } else if (args[i] == "-noassert") {
            this->shared.no_assert = true;
        } else if (args[i] == "-defer") {
            defer = true;
        }
    }
    extra_args(f, filename, args, args.size() - 1);

    AST::current_filename = filename;
    AST::set_line_num = &set_line_num;
    AST::get_line_num = &get_line_num;

    bool dump_ast1 = this->shared.debug_flag;
    bool dump_ast2 = this->shared.debug_flag;
    bool dont_redefine = false;
    bool default_nettype_wire = true;

    AST::AstNode *current_ast = parse(filename);

    AST::process(design, current_ast, dump_ast1, dump_ast2, false, false, false, false, false, false, false, false, false, false, false, false, false,
                 false, dont_redefine, false, defer, default_nettype_wire);
    delete current_ast;
}

YOSYS_NAMESPACE_END
