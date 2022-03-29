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
#ifndef _GET_PORTS_H_
#define _GET_PORTS_H_

#include "get_cmd.h"

USING_YOSYS_NAMESPACE

struct GetPorts : public GetCmd {
    GetPorts() : GetCmd("get_ports", "Print matching ports") {}

  private:
    std::string TypeName() override;
    std::string SelectionType() override;
    /* void execute(std::vector<std::string> args, RTLIL::Design* design) override; */
    SelectionObjects ExtractSelection(RTLIL::Design *design, const CommandArgs &args) override;
    void ExecuteSelection(RTLIL::Design *design, const CommandArgs &args) override;
};

#endif // GET_PORTS_H_
