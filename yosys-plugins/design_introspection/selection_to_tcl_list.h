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
