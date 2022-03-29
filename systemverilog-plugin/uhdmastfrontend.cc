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

namespace UHDM
{
extern void visit_object(vpiHandle obj_h, int indent, const char *relation, std::set<const BaseClass *> *visited, std::ostream &out,
                         bool shallowVisit = false);
}

YOSYS_NAMESPACE_BEGIN

struct UhdmAstFrontend : public UhdmCommonFrontend {
    UhdmAstFrontend() : UhdmCommonFrontend("uhdm", "read UHDM file") {}
    void help() override
    {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("    read_uhdm [options] [filename]\n");
        log("\n");
        log("Load design from a UHDM file into the current design\n");
        log("\n");
        this->print_read_options();
    }
    AST::AstNode *parse(std::string filename) override
    {
        UHDM::Serializer serializer;

        std::vector<vpiHandle> restoredDesigns = serializer.Restore(filename);
        for (auto design : restoredDesigns) {
            std::stringstream strstr;
            UHDM::visit_object(design, 1, "", &this->shared.report.unhandled, this->shared.debug_flag ? std::cout : strstr);
        }
        UhdmAst uhdm_ast(this->shared);
        AST::AstNode *current_ast = uhdm_ast.visit_designs(restoredDesigns);
        if (!this->report_directory.empty()) {
            this->shared.report.write(this->report_directory);
        }
        for (auto design : restoredDesigns)
            vpi_release_handle(design);
        return current_ast;
    }
    void call_log_header(RTLIL::Design *design) override { log_header(design, "Executing UHDM frontend.\n"); }
} UhdmAstFrontend;

YOSYS_NAMESPACE_END
