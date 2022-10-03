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
#include "get_nets.h"

USING_YOSYS_NAMESPACE

std::string GetNets::TypeName() { return "net"; }

std::string GetNets::SelectionType() { return "w"; }

GetNets::SelectionObjects GetNets::ExtractSelection(RTLIL::Design *design, const CommandArgs &args)
{
    SelectionObjects selected_objects;
    for (auto module : design->selected_modules()) {
        for (auto wire : module->selected_wires()) {
            if (args.filters.size() > 0) {
                Filter filter = args.filters.at(0);
                std::string attr_value = wire->get_string_attribute(RTLIL::IdString(RTLIL::escape_id(filter.first)));
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
