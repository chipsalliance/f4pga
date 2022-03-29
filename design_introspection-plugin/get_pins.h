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
#ifndef _GET_PINS_H_
#define _GET_PINS_H_

#include "get_cmd.h"

USING_YOSYS_NAMESPACE

struct GetPins : public GetCmd {
    GetPins() : GetCmd("get_pins", "Print matching pins") {}

  private:
    std::string TypeName() override;
    std::string SelectionType() override;
    SelectionObjects ExtractSelection(RTLIL::Design *design, const CommandArgs &args) override;
    void ExecuteSelection(RTLIL::Design *design, const CommandArgs &args) override;
    void ExtractSingleSelection(SelectionObjects &objects, RTLIL::Design *design, const std::string &port_name, const CommandArgs &args);
};

#endif // GET_PINS_H_
