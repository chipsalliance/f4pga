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
#include "selection_to_tcl_list.h"

#include "kernel/log.h"
#include "kernel/rtlil.h"

USING_YOSYS_NAMESPACE

void SelectionToTclList::help()
{
    //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
    log("\n");
    log("   selection_to_tcl_list selection\n");
    log("\n");
    log("Extract the current selection to a Tcl List with selection object names. \n");
    log("\n");
}

void SelectionToTclList::execute(std::vector<std::string> args, RTLIL::Design *design)
{
    if (args.size() == 1) {
        log_error("Incorrect number of arguments");
    }
    extra_args(args, 1, design);

    Tcl_Interp *interp = yosys_get_tcl_interp();
    Tcl_Obj *tcl_list = Tcl_NewListObj(0, NULL);

    auto &selection = design->selection();
    if (selection.empty()) {
        log_warning("Selection is empty\n");
    }

    for (auto mod : design->modules()) {
        if (selection.selected_module(mod->name)) {
            for (auto wire : mod->wires()) {
                if (selection.selected_member(mod->name, wire->name)) {
                    AddObjectNameToTclList(mod->name, wire->name, tcl_list);
                }
            }
            for (auto &it : mod->memories) {
                if (selection.selected_member(mod->name, it.first)) {
                    AddObjectNameToTclList(mod->name, it.first, tcl_list);
                }
            }
            for (auto cell : mod->cells()) {
                if (selection.selected_member(mod->name, cell->name)) {
                    AddObjectNameToTclList(mod->name, cell->name, tcl_list);
                }
            }
            for (auto &it : mod->processes) {
                if (selection.selected_member(mod->name, it.first)) {
                    AddObjectNameToTclList(mod->name, it.first, tcl_list);
                }
            }
        }
    }
    Tcl_SetObjResult(interp, tcl_list);
}

void SelectionToTclList::AddObjectNameToTclList(RTLIL::IdString &module, RTLIL::IdString &object, Tcl_Obj *tcl_list)
{
    std::string name = RTLIL::unescape_id(module) + "/" + RTLIL::unescape_id(object);
    Tcl_Obj *value_obj = Tcl_NewStringObj(name.c_str(), name.size());
    Tcl_ListObjAppendElement(yosys_get_tcl_interp(), tcl_list, value_obj);
}
