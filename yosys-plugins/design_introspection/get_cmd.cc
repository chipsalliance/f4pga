#include "get_cmd.h"

USING_YOSYS_NAMESPACE

void GetCmd::help()
{
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

void GetCmd::ExecuteSelection(RTLIL::Design *design, const CommandArgs &args)
{
    std::vector<std::string> selection_args;
    // Add name of top module to selection string
    std::transform(args.selection_objects.begin(), args.selection_objects.end(), std::back_inserter(selection_args),
                   [&](const std::string &obj) { return RTLIL::unescape_id(design->top_module()->name) + "/" + SelectionType() + ":" + obj; });
    extra_args(selection_args, 0, design);
    if (design->selected_modules().empty()) {
        if (!args.is_quiet) {
            log_warning("Specified %s not found in design\n", TypeName().c_str());
        }
    }
}

void GetCmd::PackToTcl(const SelectionObjects &objects)
{
    Tcl_Obj *tcl_result;
    if (objects.size() == 1) {
        tcl_result = Tcl_NewStringObj(objects.at(0).c_str(), -1);
    } else {
        tcl_result = Tcl_NewListObj(0, NULL);
        for (const auto &object : objects) {
            Tcl_Obj *value_obj = Tcl_NewStringObj(object.c_str(), -1);
            Tcl_ListObjAppendElement(yosys_get_tcl_interp(), tcl_result, value_obj);
        }
    }
    Tcl_SetObjResult(yosys_get_tcl_interp(), tcl_result);
}

GetCmd::CommandArgs GetCmd::ParseCommand(const std::vector<std::string> &args)
{
    CommandArgs parsed_args{.filters = Filters(), .is_quiet = false, .selection_objects = SelectionObjects()};
    size_t argidx(0);
    for (argidx = 1; argidx < args.size(); argidx++) {
        std::string arg = args[argidx];
        if (arg == "-quiet") {
            parsed_args.is_quiet = true;
            continue;
        }

        if (arg == "-filter" and argidx + 1 < args.size()) {
            std::string filter_arg = args[++argidx];

            // Remove spaces
            filter_arg.erase(std::remove_if(filter_arg.begin(), filter_arg.end(), isspace), filter_arg.end());

            // Parse filters
            // TODO Add support for multiple condition expression
            // Currently only a single == is supported
            std::regex filter_attr_regex("(\\w+\\s?==\\s?\\w+)([(||)(&&)]*)");
            std::regex_token_iterator<std::string::iterator> regex_end;
            std::regex_token_iterator<std::string::iterator> matches(filter_arg.begin(), filter_arg.end(), filter_attr_regex, 1);
            if (matches == regex_end) {
                log_warning("Currently -filter switch supports only a single "
                            "'equal(==)' condition expression, the rest will be "
                            "ignored\n");
            }

            while (matches != regex_end) {
                std::string filter(*matches++);
                auto separator = filter.find("==");
                if (separator == std::string::npos) {
                    log_cmd_error("Incorrect filter expression: %s\n", args[argidx].c_str());
                }
                parsed_args.filters.emplace_back(filter.substr(0, separator), filter.substr(separator + 2));
            }
            if (parsed_args.filters.size() > 1) {
                log_warning("Currently -filter switch supports only a single "
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
    std::copy(args.begin() + argidx, args.end(), std::back_inserter(parsed_args.selection_objects));
    return parsed_args;
}

void GetCmd::execute(std::vector<std::string> args, RTLIL::Design *design)
{
    if (design->top_module() == nullptr) {
        log_cmd_error("No top module detected\n");
    }

    CommandArgs parsed_args(ParseCommand(args));
    ExecuteSelection(design, parsed_args);
    PackToTcl(ExtractSelection(design, parsed_args));
}
