/*
 *  yosys -- Yosys Open SYnthesis Suite
 *
 *  Copyright (C) 2012  Clifford Wolf <clifford@clifford.at>
 *  Copyright (C) 2020  The Symbiflow Authors
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */
#include "get_ports.h"

USING_YOSYS_NAMESPACE

std::string GetPorts::TypeName() { return "port"; }

std::string GetPorts::SelectionType() { return "x"; }

void GetPorts::ExecuteSelection([[gnu::unused]] RTLIL::Design* design,
                               [[gnu::unused]] const CommandArgs& args) {
}

GetPorts::SelectionObjects GetPorts::ExtractSelection(RTLIL::Design* design,
                                                      const CommandArgs& args) {
    std::string port_name = args.selection_objects.at(0);
    std::string port_str(port_name.size(), '\0');
    int bit(0);
    if (!sscanf(port_name.c_str(), "%[^[][%d]", &port_str[0], &bit)) {
	log_error("Couldn't find port %s\n", port_name.c_str());
    }

    port_str.resize(strlen(port_str.c_str()));
    RTLIL::IdString port_id(RTLIL::escape_id(port_str));
    SelectionObjects objects;
    if (auto wire = design->top_module()->wire(port_id)) {
	if (wire->port_input || wire->port_output) {
	    if (bit >= wire->start_offset &&
	        bit < wire->start_offset + wire->width) {
		objects.push_back(port_name);
	    }
	}
    }
    if (objects.size() == 0 and !args.is_quiet) {
	log_warning("Couldn't find port matching %s\n", port_name.c_str());
    }
    return objects;
}

