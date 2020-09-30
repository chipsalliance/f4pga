#include "get_cmd.h"

USING_YOSYS_NAMESPACE

void GetCmd::help() {
    //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
    log("\n");
    log("   get_%ss [-quiet] [-filter filter_expression] "
        "<%s_selection> \n",
        TypeName().c_str(), TypeName().c_str());
    log("\n");
    log("Get matching %ss\n", TypeName().c_str());
    log("\n");
    log("Print the output to stdout too. This is useful when all Yosys "
        "is "
        "executed.\n");
    log("\n");
    log("    -filter\n");
    log("        Name and value of attribute to be taken into "
        "account.\n");
    log("        e.g. -filter { attr == \"true\" }\n");
    log("\n");
    log("    -quiet\n");
    log("        Don't print the result of the execution to stdout.\n");
    log("\n");
    log("    <selection_pattern>\n");
    log("        Selection of %s names. Default are all %ss in the "
        "design.\n",
        TypeName().c_str(), TypeName().c_str());
    log("\n");
}

void GetCmd::ExecuteSelection(RTLIL::Design* design, std::vector<std::string>& args, size_t argidx, bool is_quiet) {
    std::vector<std::string> selection_args;
    // Add name of top module to selection string
    std::transform(args.begin() + argidx, args.end(),
                   std::back_inserter(selection_args), [&](std::string& obj) {
	               return RTLIL::unescape_id(design->top_module()->name) + "/" +
	                      SelectionType() + ":" + obj;
                   });
    extra_args(selection_args, 0, design);
    if (design->selected_modules().empty()) {
	if (!is_quiet) {
	    log_warning("Specified %s not found in design\n", TypeName().c_str());
	}
    }
}

void GetCmd::execute(std::vector<std::string> args, RTLIL::Design* design) {
    if (design->top_module() == nullptr) {
	log_cmd_error("No top module detected\n");
    }

    size_t argidx;
    Filters filters;
    bool is_quiet = false;

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
	    if (filters.size() > 1) {
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

    ExecuteSelection(design, args, argidx, is_quiet);

    // Pack the selected nets into Tcl List
    Tcl_Interp* interp = yosys_get_tcl_interp();
    Tcl_Obj* tcl_list = Tcl_NewListObj(0, NULL);
    for (auto module : design->selected_modules()) {
	ExtractSelection(tcl_list, module, filters, is_quiet);
    }
    if (!is_quiet) {
	log("\n");
    }
    Tcl_SetObjResult(interp, tcl_list);
}
