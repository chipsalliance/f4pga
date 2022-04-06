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
        if (this->shared.debug_flag || !this->report_directory.empty()) {
            for (auto design : restoredDesigns) {
                std::stringstream strstr;
                UHDM::visit_object(design, 1, "", &this->shared.report.unhandled, this->shared.debug_flag ? std::cout : strstr);
            }
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
