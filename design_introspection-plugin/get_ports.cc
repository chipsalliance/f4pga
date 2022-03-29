/*
 * Copyright (C) 2019-2022 The SymbiFlow Authors
 *
 * Use of this source code is governed by a ISC-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/ISC
 *
 * SPDX-License-Identifier: ISC
 *
 */
#include "get_ports.h"
#include "../common/utils.h"

USING_YOSYS_NAMESPACE

std::string GetPorts::TypeName() { return "port"; }

std::string GetPorts::SelectionType() { return "x"; }

void GetPorts::ExecuteSelection([[gnu::unused]] RTLIL::Design *design, [[gnu::unused]] const CommandArgs &args) {}

GetPorts::SelectionObjects GetPorts::ExtractSelection(RTLIL::Design *design, const CommandArgs &args)
{
    std::string port_name = args.selection_objects.at(0);
    trim(port_name);
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
            if (bit >= wire->start_offset && bit < wire->start_offset + wire->width) {
                objects.push_back(port_name);
            }
        }
    }
    if (objects.size() == 0 and !args.is_quiet) {
        log_warning("Couldn't find port matching %s\n", port_name.c_str());
    }
    return objects;
}
