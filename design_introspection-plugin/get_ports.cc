#include "get_ports.h"

USING_YOSYS_NAMESPACE

void GetPorts::help() {
    //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
    log("\n");
    log("   get_ports <port_name> \n");
    log("\n");
    log("Get matching ports\n");
    log("\n");
    log("Print the output to stdout too. This is useful when all Yosys is "
        "executed\n");
    log("\n");
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
