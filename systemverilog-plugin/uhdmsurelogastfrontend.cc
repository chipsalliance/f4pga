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

#include "Surelog/ErrorReporting/Report.h"
#include "Surelog/surelog.h"

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
    if ((!noFatalErrors) || (!success) || (errors->getErrorStats().nbError))
        codedReturn |= 1;
    if (codedReturn) {
        log_error("Error when parsing design. Aborting!\n");
    }
    return the_design;
}

struct UhdmSurelogAstFrontend : public UhdmCommonFrontend {
    UhdmSurelogAstFrontend(std::string name, std::string short_help) : UhdmCommonFrontend(name, short_help) {}
    UhdmSurelogAstFrontend() : UhdmCommonFrontend("verilog_with_uhdm", "generate/read UHDM file") {}
    void help() override
    {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("    read_verilog_with_uhdm [options] [filenames]\n");
        log("\n");
        log("Read SystemVerilog files using Surelog into the current design\n");
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
        // Force -parse flag settings even if it wasn't specified
        clp->setwritePpOutput(true);
        clp->setParse(true);
        clp->setCompile(true);
        clp->setElaborate(true);

        SURELOG::scompiler *compiler = nullptr;
        const std::vector<vpiHandle> uhdm_design = executeCompilation(symbolTable, errors, clp, compiler);
        if (this->shared.debug_flag || !this->report_directory.empty()) {
            for (auto design : uhdm_design) {
                std::stringstream strstr;
                UHDM::visit_object(design, 1, "", &this->shared.report.unhandled, this->shared.debug_flag ? std::cout : strstr);
            }
        }

        SURELOG::shutdown_compiler(compiler);
        delete clp;
        delete symbolTable;
        delete errors;
        // on parse_only mode, don't try to load design
        // into yosys
        if (this->shared.parse_only)
            return nullptr;

        UhdmAst uhdm_ast(this->shared);
        AST::AstNode *current_ast = uhdm_ast.visit_designs(uhdm_design);
        if (!this->report_directory.empty()) {
            this->shared.report.write(this->report_directory);
        }

        return current_ast;
    }
    void call_log_header(RTLIL::Design *design) override { log_header(design, "Executing Verilog with UHDM frontend.\n"); }
} UhdmSurelogAstFrontend;

struct UhdmSystemVerilogFrontend : public UhdmSurelogAstFrontend {
    UhdmSystemVerilogFrontend() : UhdmSurelogAstFrontend("systemverilog", "read SystemVerilog files") {}
    void help() override
    {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("    read_systemverilog [options] [filenames]\n");
        log("\n");
        log("Read SystemVerilog files using Surelog into the current design\n");
        log("\n");
        this->print_read_options();
    }
} UhdmSystemVerilogFrontend;

YOSYS_NAMESPACE_END
