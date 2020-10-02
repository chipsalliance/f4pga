#include "get_pins.h"

USING_YOSYS_NAMESPACE

std::string GetPins::TypeName() { return "pin"; }

std::string GetPins::SelectionType() { return "c"; }

void GetPins::execute(std::vector<std::string> args, RTLIL::Design* design) {
    if (design->top_module() == nullptr) {
	log_cmd_error("No top module detected\n");
    }

    CommandArgs parsed_args(ParseCommand(args));
    Tcl_Obj* tcl_list = Tcl_NewListObj(0, NULL);
    for (auto obj : parsed_args.selection_objects) {
	size_t port_separator = obj.find_last_of("/");
	std::string cell = obj.substr(0, port_separator);
	std::string port = obj.substr(port_separator + 1);
	SelectionObjects selection{RTLIL::unescape_id(design->top_module()->name) + "/" +
	       SelectionType() + ":" + cell};
	extra_args(selection, 0, design);
	ExtractSingleSelection(tcl_list, design, port, parsed_args);
    }
    if (!parsed_args.is_quiet) {
	log("\n");
    }
    Tcl_SetObjResult(yosys_get_tcl_interp(), tcl_list);
}

void GetPins::ExtractSingleSelection(Tcl_Obj* tcl_list, RTLIL::Design* design,
                                     const std::string& port_name,
                                     const CommandArgs& args) {
    if (design->selected_modules().empty()) {
	if (!args.is_quiet) {
	    log_warning("Specified %s not found in design\n",
	                TypeName().c_str());
	}
    }
    for (auto module : design->selected_modules()) {
	for (auto cell : module->selected_cells()) {
	    if (!cell->hasPort(RTLIL::escape_id(port_name))) {
		continue;
	    }
	    if (args.filters.size() > 0) {
		Filter filter = args.filters.at(0);
		std::string attr_value = cell->get_string_attribute(
		    RTLIL::IdString(RTLIL::escape_id(filter.first)));
		if (attr_value.compare(filter.second)) {
		    continue;
		}
	    }
	    std::string pin_name(RTLIL::unescape_id(cell->name) + "/" + port_name);
	    if (!args.is_quiet) {
		log("%s ", pin_name.c_str());
	    }
	    Tcl_Obj* value_obj = Tcl_NewStringObj(pin_name.c_str(), -1);
	    Tcl_ListObjAppendElement(yosys_get_tcl_interp(), tcl_list,
	                             value_obj);
	}
    }
}

