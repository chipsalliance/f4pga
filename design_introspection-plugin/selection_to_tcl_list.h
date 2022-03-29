/*
 * Copyright (C) 2019-2022 The SymbiFlow Authors
 *
 * Use of this source code is governed by a ISC-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/ISC
 *
 * SPDX-License-Identifier: ISC
 */
#ifndef _SELECTION_TO_TCL_LIST_H_
#define _SELECTION_TO_TCL_LIST_H_

#include "kernel/register.h"

USING_YOSYS_NAMESPACE

struct SelectionToTclList : public Pass {
    SelectionToTclList() : Pass("selection_to_tcl_list", "Extract selection to TCL list") {}

    void help() override;
    void execute(std::vector<std::string> args, RTLIL::Design *design) override;

  private:
    void AddObjectNameToTclList(RTLIL::IdString &module, RTLIL::IdString &object, Tcl_Obj *tcl_list);
};

#endif // SELECTION_TO_TCL_LIST_H_
