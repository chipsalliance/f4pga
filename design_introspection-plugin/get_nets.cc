#include "get_nets.h"

USING_YOSYS_NAMESPACE

std::string GetNets::TypeName() { return "net"; }

std::string GetNets::SelectionType() { return "w"; }

void GetNets::ExtractSelection(Tcl_Obj* tcl_list, RTLIL::Module* module,
                               const CommandArgs& args) {
    for (auto wire : module->selected_wires()) {
	if (args.filters.size() > 0) {
	    Filter filter = args.filters.at(0);
	    std::string attr_value = wire->get_string_attribute(
	        RTLIL::IdString(RTLIL::escape_id(filter.first)));
	    if (attr_value.compare(filter.second)) {
		continue;
	    }
	}
	if (!args.is_quiet) {
	    log("%s ", id2cstr(wire->name));
	}
	Tcl_Obj* value_obj = Tcl_NewStringObj(id2cstr(wire->name), -1);
	Tcl_ListObjAppendElement(yosys_get_tcl_interp(), tcl_list, value_obj);
    }
}
