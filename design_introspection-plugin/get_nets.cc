#include "get_nets.h"
#include <regex>
#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/rtlil.h"

USING_YOSYS_NAMESPACE

void GetNets::help() {
    //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
    log("\n");
    log("   get_nets [-quiet] [-filter filter_expression] <net_selection> \n");
    log("\n");
    log("Get matching nets\n");
    log("\n");
    log("Print the output to stdout too. This is useful when all Yosys is "
        "executed.\n");
    log("\n");
    log("    -filter\n");
    log("        Name and value of attribute to be taken into account.\n");
    log("        e.g. -filter { attr == \"true\" }\n");
    log("\n");
    log("    -quiet\n");
    log("        Don't print the result of the execution to stdout.\n");
    log("\n");
    log("    <net_selection>\n");
    log("        Selection of net name. Default are all nets in the design.\n");
    log("\n");
}

void GetNets::execute(std::vector<std::string> args, RTLIL::Design* design) {
    RTLIL::Module* top_module = design->top_module();
    if (top_module == nullptr) {
	log_cmd_error("No top module detected\n");
    }

    size_t argidx;
    std::vector<std::pair<std::string, std::string>> filters;
    bool is_quiet = false;
    bool has_filter = false;

    // Parse command arguments
    for (argidx = 1; argidx < args.size(); argidx++) {
	std::string arg = args[argidx];
	if (arg == "-quiet") {
	    is_quiet = true;
	    continue;
	}

	if (arg == "-filter" and argidx + 1 < args.size()) {
	    std::string filter_arg = args[++argidx];

	    // Remove spaces
	    filter_arg.erase(
	        std::remove_if(filter_arg.begin(), filter_arg.end(), isspace),
	        filter_arg.end());

	    // Parse filters
	    std::regex filter_attr_regex("(\\w+\\s?==\\s?\\w+)([(||)(&&)]*)");
	    std::regex_token_iterator<std::string::iterator> regex_end;
	    std::regex_token_iterator<std::string::iterator> matches(
	        filter_arg.begin(), filter_arg.end(), filter_attr_regex, 1);
	    if (matches == regex_end) {
		log_warning(
		    "Currently -filter switch supports only a single "
		    "'equal(==)' condition expression, the rest will be "
		    "ignored\n");
	    }

	    while (matches != regex_end) {
		std::string filter(*matches++);
		auto separator = filter.find("==");
		if (separator == std::string::npos) {
		    log_cmd_error("Incorrect filter expression: %s\n",
		                  args[argidx].c_str());
		}
		filters.emplace_back(filter.substr(0, separator),
		                     filter.substr(separator + 2));
	    }
	    size_t filter_cnt = filters.size();
	    has_filter = filter_cnt > 0;
	    if (filter_cnt > 1) {
		log_warning(
		    "Currently -filter switch supports only a single "
		    "'equal(==)' condition expression, the rest will be "
		    "ignored\n");
	    }
	    continue;
	}

	if (arg.size() > 0 and arg[0] == '-') {
	    log_cmd_error("Unknown option %s.\n", arg.c_str());
	}

	break;
    }

    // Add name of top module to selection string
    std::vector<std::string> selection_args;
    std::transform(args.begin() + argidx, args.end(),
                   std::back_inserter(selection_args), [&](std::string& net) {
	               return RTLIL::unescape_id(top_module->name) +
	                      "/w:" + net;
                   });

    // Execute the selection
    extra_args(selection_args, 0, design);
    if (design->selected_modules().empty()) {
	if (!is_quiet) {
	    log_warning("Specified net not found in design\n");
	}
    }

    // Pack the selected nets into Tcl List
    Tcl_Interp* interp = yosys_get_tcl_interp();
    Tcl_Obj* tcl_list = Tcl_NewListObj(0, NULL);
    for (auto module : design->selected_modules()) {
	for (auto wire : module->selected_wires()) {
	    if (has_filter) {
		std::pair<std::string, std::string> filter = filters.at(0);
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
	    Tcl_ListObjAppendElement(interp, tcl_list, value_obj);
	}
    }
    if (!is_quiet) {
	log("\n");
    }
    Tcl_SetObjResult(interp, tcl_list);
}
