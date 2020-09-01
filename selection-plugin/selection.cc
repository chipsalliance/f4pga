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


struct SelectionToTclList : public Pass {
	SelectionToTclList() : Pass("selection_to_tcl_list", "Extract selection to TCL list") {}

	void help() override
	{
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
		log("\n");
		log("   selection_to_tcl_list selection\n");
		log("\n");
		log("Extract the current selection to a Tcl List with selection object names. \n");
		log("\n");
	}

	void AddObjectNameToTclList(RTLIL::IdString& module, RTLIL::IdString& object, Tcl_Obj* tcl_list) {
		std::string name = RTLIL::unescape_id(module) + "/" + RTLIL::unescape_id(object);
		Tcl_Obj* value_obj = Tcl_NewStringObj(name.c_str(), name.size());
		Tcl_ListObjAppendElement(yosys_get_tcl_interp(), tcl_list, value_obj);
	}

	void execute(std::vector<std::string> args, RTLIL::Design* design) override
	{
		if (args.size() == 1) {
			log_error("Incorrect number of arguments");
		}
		extra_args(args, 1, design);

		Tcl_Interp *interp = yosys_get_tcl_interp();
		Tcl_Obj* tcl_list = Tcl_NewListObj(0, NULL);

		auto& selection = design->selection();
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

} SelectionToTclList;

PRIVATE_NAMESPACE_END
