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
#ifndef _GET_NETS_H_
#define _GET_NETS_H_

#include "get_cmd.h"

USING_YOSYS_NAMESPACE

struct GetNets : public GetCmd {
    GetNets() : GetCmd("get_nets", "Print matching nets") {}

    std::string TypeName() override;
    std::string SelectionType() override;
    SelectionObjects ExtractSelection(RTLIL::Design *design, const CommandArgs &args) override;
};

#endif // GET_NETS_H_
