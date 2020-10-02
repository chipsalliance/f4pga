#include "get_cells.h"

USING_YOSYS_NAMESPACE

std::string GetCells::TypeName() { return "cell"; }

std::string GetCells::SelectionType() { return "c"; }

GetCells::SelectionObjects GetCells::ExtractSelection(RTLIL::Design* design, const CommandArgs& args) {
    SelectionObjects selected_objects;
    for (auto module : design->selected_modules()) {
	for (auto cell : module->selected_cells()) {
	    if (args.filters.size() > 0) {
		Filter filter = args.filters.at(0);
		std::string attr_value = cell->get_string_attribute(
		    RTLIL::IdString(RTLIL::escape_id(filter.first)));
		if (attr_value.compare(filter.second)) {
		    continue;
		}
	    }
	    std::string object_name(RTLIL::unescape_id(cell->name));
	    if (!args.is_quiet) {
		log("%s ", object_name.c_str());
	    }
	    selected_objects.push_back(object_name);
	}
    }
    return selected_objects;
}
