/*
 * Copyright (C) 2019-2022 The SymbiFlow Authors
 *
 * Use of this source code is governed by a ISC-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/ISC
 *
 * SPDX-License-Identifier: ISC
 */
#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/rtlil.h"

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN

void register_in_tcl_interpreter(const std::string &command)
{
    Tcl_Interp *interp = yosys_get_tcl_interp();
    std::string tcl_script = stringf("proc %s args { return [yosys %s {*}$args] }", command.c_str(), command.c_str());
    Tcl_Eval(interp, tcl_script.c_str());
}

struct GetParam : public Pass {
    GetParam() : Pass("getparam", "get parameter on object") { register_in_tcl_interpreter(pass_name); }

    void help() override
    {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("   getparam name selection\n");
        log("\n");
        log("Get the given parameter on the selected object. \n");
        log("\n");
    }

    void execute(std::vector<std::string> args, RTLIL::Design *design) override
    {
        if (args.size() == 1) {
            log_error("Incorrect number of arguments");
        }
        extra_args(args, 2, design);

        auto param = RTLIL::IdString(RTLIL::escape_id(args.at(1)));
        Tcl_Interp *interp = yosys_get_tcl_interp();
        Tcl_Obj *tcl_list = Tcl_NewListObj(0, NULL);

        for (auto module : design->selected_modules()) {
            for (auto cell : module->selected_cells()) {
                auto params = cell->parameters;
                auto it = params.find(param);
                if (it != params.end()) {
                    std::string value;
                    auto param_obj = it->second;
                    if (param_obj.flags & RTLIL::CONST_FLAG_STRING) {
                        value = param_obj.decode_string();
                    } else {
                        value = std::to_string(param_obj.as_int());
                    }
                    Tcl_Obj *value_obj = Tcl_NewStringObj(value.c_str(), value.size());
                    Tcl_ListObjAppendElement(interp, tcl_list, value_obj);
                }
            }
        }
        Tcl_SetObjResult(interp, tcl_list);
    }

} GetParam;

PRIVATE_NAMESPACE_END
