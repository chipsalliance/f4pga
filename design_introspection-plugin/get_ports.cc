#include "get_ports.h"

USING_YOSYS_NAMESPACE

std::string GetPorts::TypeName() { return "port"; }

std::string GetPorts::SelectionType() { return "x"; }

void GetPorts::ExtractSelection(Tcl_Obj* tcl_list, RTLIL::Module* module,
                                GetCmd::Filters& filters, bool is_quiet) {
    for (auto wire : module->selected_wires()) {
	if (!wire->port_input and !wire->port_output) {
	    continue;
	}
	if (filters.size() > 0) {
	    Filter filter = filters.at(0);
	    std::string attr_value = wire->get_string_attribute(
	        RTLIL::IdString(RTLIL::escape_id(filter.first)));
	    if (attr_value.compare(filter.second)) {
		continue;
	    }
	}
	if (!is_quiet) {
	    log("%s ", id2cstr(wire->name));
	}
	Tcl_Obj* value_obj = Tcl_NewStringObj(id2cstr(wire->name), -1);
	Tcl_ListObjAppendElement(yosys_get_tcl_interp(), tcl_list, value_obj);
    }
}

void GetPorts::execute(std::vector<std::string> args, RTLIL::Design* design) {
    if (args.size() < 2) {
	log_cmd_error("No port specified.\n");
    }
    RTLIL::Module* top_module = design->top_module();
    if (top_module == nullptr) {
	log_cmd_error("No top module detected\n");
    }
    // TODO handle more than one port
    std::string port_name = args.at(1);
    std::string port_str(port_name.size(), '\0');
    int bit(0);
    if (!sscanf(port_name.c_str(), "%[^[][%d]", &port_str[0], &bit)) {
	log_error("Couldn't find port %s\n", port_name.c_str());
    }

    port_str.resize(strlen(port_str.c_str()));
    RTLIL::IdString port_id(RTLIL::escape_id(port_str));
    Tcl_Interp* interp = yosys_get_tcl_interp();
    if (auto wire = top_module->wire(port_id)) {
	if (wire->port_input || wire->port_output) {
	    if (bit >= wire->start_offset &&
	        bit < wire->start_offset + wire->width) {
		Tcl_Obj* tcl_string = Tcl_NewStringObj(port_name.c_str(), -1);
		Tcl_SetObjResult(interp, tcl_string);
		log("Found port %s\n", port_name.c_str());
		return;
	    }
	}
    }
    log_error("Couldn't find port %s\n", port_name.c_str());
}
