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
