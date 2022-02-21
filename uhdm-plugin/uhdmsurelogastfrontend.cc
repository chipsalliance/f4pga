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

#include "UhdmAst.h"
#include "frontends/ast/ast.h"
#include "kernel/yosys.h"
#include "uhdmcommonfrontend.h"

#if defined(_MSC_VER)
#include <direct.h>
#include <process.h>
#else
#include <sys/param.h>
#include <unistd.h>
#endif

#include "ErrorReporting/Report.h"
#include "surelog.h"

namespace UHDM
{
extern void visit_object(vpiHandle obj_h, int indent, const char *relation, std::set<const BaseClass *> *visited, std::ostream &out,
                         bool shallowVisit = false);
}

YOSYS_NAMESPACE_BEGIN

std::vector<vpiHandle> executeCompilation(SURELOG::SymbolTable *symbolTable, SURELOG::ErrorContainer *errors, SURELOG::CommandLineParser *clp,
                                          SURELOG::scompiler *compiler)
{
    bool success = true;
    bool noFatalErrors = true;
    unsigned int codedReturn = 0;
    clp->setWriteUhdm(false);
    errors->printMessages(clp->muteStdout());
    std::vector<vpiHandle> the_design;
    if (success && (!clp->help())) {
        compiler = SURELOG::start_compiler(clp);
        if (!compiler)
            codedReturn |= 1;
        the_design.push_back(SURELOG::get_uhdm_design(compiler));
    }
    SURELOG::ErrorContainer::Stats stats;
    if (!clp->help()) {
        stats = errors->getErrorStats();
        if (stats.nbFatal)
            codedReturn |= 1;
        if (stats.nbSyntax)
            codedReturn |= 2;
    }
    bool noFErrors = true;
    if (!clp->help())
        noFErrors = errors->printStats(stats, clp->muteStdout());
    if (noFErrors == false) {
        noFatalErrors = false;
    }
    if ((!noFatalErrors) || (!success))
        codedReturn |= 1;
    return the_design;
}

struct UhdmSurelogAstFrontend : public UhdmCommonFrontend {
    UhdmSurelogAstFrontend() : UhdmCommonFrontend("verilog_with_uhdm", "generate/read UHDM file") {}
    void print_read_options() override
    {
        log("    -process\n");
        log("        loads design from given UHDM file\n");
        log("\n");
        UhdmCommonFrontend::print_read_options();
    }
    void help() override
    {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("    read_verilog_with_uhdm [options] [filenames]\n");
        log("\n");
        log("Generate or load design from a UHDM file into the current design\n");
        log("\n");
        this->print_read_options();
    }
    AST::AstNode *parse(std::string filename) override
    {
        std::vector<const char *> cstrings;
        cstrings.reserve(this->args.size());
        for (size_t i = 0; i < this->args.size(); ++i)
            cstrings.push_back(const_cast<char *>(this->args[i].c_str()));

        SURELOG::SymbolTable *symbolTable = new SURELOG::SymbolTable();
        SURELOG::ErrorContainer *errors = new SURELOG::ErrorContainer(symbolTable);
        SURELOG::CommandLineParser *clp = new SURELOG::CommandLineParser(errors, symbolTable, false, false);
        bool success = clp->parseCommandLine(cstrings.size(), &cstrings[0]);
        if (!success) {
            log_error("Error parsing Surelog arguments!\n");
        }
        SURELOG::scompiler *compiler = nullptr;
        const std::vector<vpiHandle> uhdm_design = executeCompilation(symbolTable, errors, clp, compiler);

        SURELOG::shutdown_compiler(compiler);
        delete clp;
        delete symbolTable;
        delete errors;

        UhdmAst uhdm_ast(this->shared);
        AST::AstNode *current_ast = uhdm_ast.visit_designs(uhdm_design);
        if (report_directory != "") {
            shared.report.write(report_directory);
        }

        return current_ast;
    }
    void call_log_header(RTLIL::Design *design) override { log_header(design, "Executing Verilog with UHDM frontend.\n"); }
} UhdmSurelogAstFrontend;

YOSYS_NAMESPACE_END
