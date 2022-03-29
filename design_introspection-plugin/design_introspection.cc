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
