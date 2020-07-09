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
 */
#include "kernel/register.h"
#include "kernel/rtlil.h"
#include "kernel/log.h"

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN


void register_in_tcl_interpreter(const std::string& command) {
	Tcl_Interp* interp = yosys_get_tcl_interp();
	std::string tcl_script = stringf("proc %s args { return [yosys %s {*}$args] }", command.c_str(), command.c_str());
	Tcl_Eval(interp, tcl_script.c_str());
}

struct GetParam : public Pass {
	GetParam() : Pass("get_param", "get parameter on object") {
		register_in_tcl_interpreter(pass_name);
	}

	void help() override
	{
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
		log("\n");
		log("   get_param name selection\n");
		log("\n");
		log("Get the given parameter on the selected object. \n");
		log("\n");
	}

	void execute(std::vector<std::string> args, RTLIL::Design* design) override
	{
		if (args.size() == 1) {
			log_error("Incorrect number of arguments");
		}

		std::string param(args.at(1));
		std::string value;
		extra_args(args, 2, design);

		for (auto module : design->selected_modules()) {
			for (auto cell : module->selected_cells()) {
				auto params = cell->parameters;
				auto it = params.find(RTLIL::IdString(RTLIL::escape_id(param)));
				if (it != params.end()) {
					auto param_obj = it->second;
					if (param_obj.flags & RTLIL::CONST_FLAG_STRING) {
						value = param_obj.decode_string();
					} else {
						value = std::to_string(param_obj.as_int());
					}
				}
			}
		}

		char* tcl_param = Tcl_Alloc(value.size() + 1);
		strcpy(tcl_param, value.c_str());
		Tcl_Interp *interp = yosys_get_tcl_interp();
		Tcl_SetResult(interp, tcl_param, TCL_DYNAMIC);
	}

} GetParam;

PRIVATE_NAMESPACE_END
