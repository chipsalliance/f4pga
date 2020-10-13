#include "get_nets.h"

USING_YOSYS_NAMESPACE

std::string GetNets::TypeName() { return "net"; }

std::string GetNets::SelectionType() { return "w"; }

GetNets::SelectionObjects GetNets::ExtractSelection(RTLIL::Design* design,
                                                    const CommandArgs& args) {
    SelectionObjects selected_objects;
    for (auto module : design->selected_modules()) {
	for (auto wire : module->selected_wires()) {
	    if (args.filters.size() > 0) {
		Filter filter = args.filters.at(0);
		std::string attr_value = wire->get_string_attribute(
		    RTLIL::IdString(RTLIL::escape_id(filter.first)));
		if (attr_value.compare(filter.second)) {
		    continue;
		}
	    }
	    std::string object_name(RTLIL::unescape_id(wire->name));
	    selected_objects.push_back(object_name);
	}
    }
    if (selected_objects.size() == 0 and !args.is_quiet) {
	log_warning("Couldn't find matching net.\n");
    }
    return selected_objects;
}
