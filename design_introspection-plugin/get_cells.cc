#include "get_cells.h"

USING_YOSYS_NAMESPACE

std::string GetCells::TypeName() { return "cell"; }

std::string GetCells::SelectionType() { return "c"; }

void GetCells::ExtractSelection(Tcl_Obj* tcl_list, RTLIL::Module* module,
                               Filters& filters, bool is_quiet) {
    for (auto cell : module->selected_cells()) {
	if (filters.size() > 0) {
	    Filter filter = filters.at(0);
	    std::string attr_value = cell->get_string_attribute(
	        RTLIL::IdString(RTLIL::escape_id(filter.first)));
	    if (attr_value.compare(filter.second)) {
		continue;
	    }
	}
	if (!is_quiet) {
	    log("%s ", id2cstr(cell->name));
	}
	Tcl_Obj* value_obj = Tcl_NewStringObj(id2cstr(cell->name), -1);
	Tcl_ListObjAppendElement(yosys_get_tcl_interp(), tcl_list, value_obj);
    }
}
