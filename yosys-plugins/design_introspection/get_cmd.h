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
#ifndef _GET_CMD_H_
#define _GET_CMD_H_

#include "kernel/register.h"

USING_YOSYS_NAMESPACE

struct GetCmd : public Pass {
    using Filter = std::pair<std::string, std::string>;
    using Filters = std::vector<Filter>;
    using SelectionObjects = std::vector<std::string>;
    struct CommandArgs {
        Filters filters;
        bool is_quiet;
        SelectionObjects selection_objects;
    };

    GetCmd(const std::string &name, const std::string &description) : Pass(name, description) {}

    void help() override;
    void execute(std::vector<std::string> args, RTLIL::Design *design) override;

  protected:
    CommandArgs ParseCommand(const std::vector<std::string> &args);
    void PackToTcl(const SelectionObjects &objects);

  private:
    virtual std::string TypeName() = 0;
    virtual std::string SelectionType() = 0;
    virtual SelectionObjects ExtractSelection(RTLIL::Design *design, const CommandArgs &args) = 0;
    virtual void ExecuteSelection(RTLIL::Design *design, const CommandArgs &args);
};

#endif // GET_CMD_H_
