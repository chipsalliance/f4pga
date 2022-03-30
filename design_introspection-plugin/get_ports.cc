/*
 * Copyright 2020-2022 F4PGA Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
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
