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

#include "get_count.h"

#include "kernel/rtlil.h"

USING_YOSYS_NAMESPACE

void GetCount::help()
{
    log("\n");
    log("    get_count <options> [selection]");
    log("\n");
    log("When used from inside the TCL interpreter returns count of selected objects.\n");
    log("The object type to count may be given as an argument. Only one at a time.\n");
    log("If none is given then the total count of all selected objects is returned.\n");
    log("\n");
    log("    -modules\n");
    log("        Returns the count of modules in selection\n");
    log("\n");
    log("    -cells\n");
    log("        Returns the count of cells in selection\n");
    log("\n");
    log("    -wires\n");
    log("        Returns the count of wires in selection\n");
    log("\n");
}

void GetCount::execute(std::vector<std::string> a_Args, RTLIL::Design *a_Design)
{

    // Parse args
    ObjectType type = ObjectType::NONE;
    if (a_Args.size() < 2) {
        log_error("Invalid argument!\n");
    }

    if (a_Args[1] == "-modules") {
        type = ObjectType::MODULE;
    } else if (a_Args[1] == "-cells") {
        type = ObjectType::CELL;
    } else if (a_Args[1] == "-wires") {
        type = ObjectType::WIRE;
    } else if (a_Args[1][0] == '-') {
        log_error("Invalid argument '%s'!\n", a_Args[1].c_str());
    } else {
        log_error("Object type not specified!\n");
    }

    extra_args(a_Args, 2, a_Design);

    // Get the TCL interpreter
    Tcl_Interp *tclInterp = yosys_get_tcl_interp();

    // Count objects
    size_t moduleCount = 0;
    size_t cellCount = 0;
    size_t wireCount = 0;

    moduleCount += a_Design->selected_modules().size();
    for (auto module : a_Design->selected_modules()) {
        cellCount += module->selected_cells().size();
        wireCount += module->selected_wires().size();
    }

    size_t count = 0;
    switch (type) {
    case ObjectType::MODULE:
        count = moduleCount;
        break;
    case ObjectType::CELL:
        count = cellCount;
        break;
    case ObjectType::WIRE:
        count = wireCount;
        break;
    default:
        log_assert(false);
    }

    // Return the value as string to the TCL interpreter
    std::string value = std::to_string(count);

    Tcl_Obj *tclStr = Tcl_NewStringObj(value.c_str(), value.size());
    Tcl_SetObjResult(tclInterp, tclStr);
}
