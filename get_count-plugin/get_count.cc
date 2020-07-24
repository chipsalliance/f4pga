/*
 *  yosys -- Yosys Open SYnthesis Suite
 *
 *  Copyright (C) 2012  Clifford Wolf <clifford@clifford.at>
 *  Copyright (C) 2020  The Symbiflow Authors
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

#include "kernel/register.h"
#include "kernel/rtlil.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

void register_in_tcl_interpreter(const std::string& command) {
    Tcl_Interp* interp = yosys_get_tcl_interp();
    std::string tcl_script = stringf("proc %s args { return [yosys %s {*}$args] }", command.c_str(), command.c_str());
    Tcl_Eval(interp, tcl_script.c_str());
}

struct GetCount : public Pass {

    enum class ObjectType {
        NONE,
        MODULE,
        CELL,
        WIRE
    };

    GetCount () :
        Pass("get_count", "Returns count of various selected object types to the TCL interpreter") {
            register_in_tcl_interpreter(pass_name);
        }    

    void help() YS_OVERRIDE {
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
    
    void execute(std::vector<std::string> a_Args, RTLIL::Design* a_Design) YS_OVERRIDE {

        // Parse args
        ObjectType type = ObjectType::NONE;
        if (a_Args.size() < 2) {
            log_error("Invalid argument!\n");
        }

        if (a_Args[1] == "-modules") {
            type = ObjectType::MODULE;
        }
        else if (a_Args[1] == "-cells") {
            type = ObjectType::CELL;
        }
        else if (a_Args[1] == "-wires") {
            type = ObjectType::WIRE;
        }
        else if (a_Args[1][0] == '-') {
            log_error("Invalid argument '%s'!\n", a_Args[1].c_str());
        }
        else {
            log_error("Object type not specified!\n");
        }

        extra_args(a_Args, 2, a_Design);

        // Get the TCL interpreter
        Tcl_Interp* tclInterp = yosys_get_tcl_interp();
        Tcl_Obj*    tclList = Tcl_NewListObj(0, NULL);

        // Count objects
        size_t moduleCount = 0;
        size_t cellCount   = 0;
        size_t wireCount   = 0;

        moduleCount += a_Design->selected_modules().size();
        for (auto module : a_Design->selected_modules()) {
            cellCount += module->selected_cells().size();
            wireCount += module->selected_wires().size();
        }

        size_t count = 0;
        switch (type)
        {
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

        Tcl_Obj* tclStr = Tcl_NewStringObj(value.c_str(), value.size());
        Tcl_ListObjAppendElement(tclInterp, tclList, tclStr);
        Tcl_SetObjResult(tclInterp, tclList);
    }

} GetCount;

PRIVATE_NAMESPACE_END
