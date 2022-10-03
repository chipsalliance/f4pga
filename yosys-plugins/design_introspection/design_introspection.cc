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

#include "get_cells.h"
#include "get_count.h"
#include "get_nets.h"
#include "get_pins.h"
#include "get_ports.h"
#include "selection_to_tcl_list.h"

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN

struct DesignIntrospection {
    DesignIntrospection() {}
    GetNets get_nets_cmd;
    GetPorts get_ports_cmd;
    GetCells get_cells_cmd;
    GetPins get_pins_cmd;
    GetCount get_count_cmd;
    SelectionToTclList selection_to_tcl_list_cmd;
} DesignIntrospection;

PRIVATE_NAMESPACE_END
