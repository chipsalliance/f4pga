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

namespace UHDM
{
extern void visit_object(vpiHandle obj_h, int indent, const char *relation, std::set<const BaseClass *> *visited, std::ostream &out,
                         bool shallowVisit = false);
}

YOSYS_NAMESPACE_BEGIN

struct UhdmAstFrontend : public UhdmCommonFrontend {
    UhdmAstFrontend() : UhdmCommonFrontend("uhdm", "read UHDM file") { this->log_header_message = "Executing UHDM frontend.\n"; }
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
} UhdmAstFrontend;

YOSYS_NAMESPACE_END
