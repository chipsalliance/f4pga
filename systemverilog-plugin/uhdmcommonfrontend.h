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

#include "UhdmAst.h"
#include "frontends/ast/ast.h"
#include "kernel/yosys.h"
#include <string>
#include <vector>

YOSYS_NAMESPACE_BEGIN

struct UhdmCommonFrontend : public Frontend {
    UhdmAstShared shared;
    std::string report_directory;
    std::vector<std::string> args;
    UhdmCommonFrontend(std::string name, std::string short_help) : Frontend(name, short_help) {}
    virtual void print_read_options();
    virtual void help() = 0;
    virtual AST::AstNode *parse(std::string filename) = 0;
    virtual void call_log_header(RTLIL::Design *design) = 0;
    void execute(std::istream *&f, std::string filename, std::vector<std::string> args, RTLIL::Design *design);
};

YOSYS_NAMESPACE_END
