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
