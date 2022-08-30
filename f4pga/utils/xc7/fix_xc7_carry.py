#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright (C) 2019-2022 F4PGA Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

"""
Script for addressing CARRY4 output congestion in elaborated netlists.

Usage:

    python3 fix_carry.py < input-netlist-json > output-netlist-json

Description:

    In the 7-series SLICEL (and SLICEM) sites, there can be output congestion
    if both the CO and O of the CARRY4 are used. This congestion can be
    avoided by using a transparent/open latch or register on the output of the
    CARRY4.

    VPR does not currently support either of those options, so for now, if
    both CO and O are used, the CO output is converted into a LUT equation to
    recompute the CO output from O, DI and S.  See carry_map.v and
    clean_carry_map.v for details.

    If VPR could emit the transparent/open latch on output congestion, this
    would no longer be required.  The major problem with transparent latch
    support is that it requires constants to be routed to the G/GE/CLR/PRE
    ports, which VPR cannot express as a result of packing.

    This script identifies CARRY4 chains in the netlist, identifies if there
    is output congestion on the O and CO ports, and marks the congestion by
    changing CARRY_CO_DIRECT (e.g. directly use the CO port) to CARRY_CO_LUT
    (compute the CO value using a LUT equation).


Diagram showing one row of the 7-series CLE, focusing on O/CO congestion.
This diagram shows that if both the O and CO outputs are needed, once must
pass through the flip flop (xFF in the diagram).

                                      CLE Row

+--------------------------------------------------------------------------+
|                                                                          |
|                                                                          |
|                                               +---+                      |
|                                               |    +                     |
|                                               |     +                    |
|                                     +-------->+ O    +                   |
|              CO CHAIN               |         |       +                  |
|                                     |         |       +---------------------> xMUX
|                 ^                   |   +---->+ CO    +                  |
|                 |                   |   |     |      +                   |
|                 |                   |   |     |     +                    |
|       +---------+----------+        |   |     |    +                     |
|       |                    |        |   |     +---+                      |
|       |     CARRY ROW      |        |   |                                |
|  +--->+ S              O   +--------+   |       xOUTMUX                  |
|       |                    |        |   |                                |
|       |                    |        +   |                                |
|  +--->+ DI             CO  +-------+o+--+                                |
|       |      CI CHAIN      |        +   |                                |
|       |                    |        |   |                                |
|       +---------+----------+        |   |       xFFMUX                   |
|                 ^                   |   |                                |
|                 |                   |   |     +---+                      |
|                 +                   |   |     |    +                     |
|                                     |   +     |     +    +-----------+   |
|                                     +--+o+--->+ O    +   |           |   |
|                                         +     |       +  |    xFF    |   |
|                                         |     |       +->--D----   Q +------> xQ
|                                         |     |       +  |           |   |
|                                         +---->+ CO   +   |           |   |
|                                               |     +    +-----------+   |
|                                               |    +                     |
|                                               +---+                      |
|                                                                          |
|                                                                          |
+--------------------------------------------------------------------------+


This script operates on a slightly different cell structure than a plain CARRY4.
carry_map.v converts the CARRY4 into:

                                              +------------------+  +-----------------+
                                              |                  |  |                 |
                                              |              CO3 +->+ CARRY_CO_DIRECT |
                                              |                  |  |                 |
                                              | DI3              |  +-----------------+
                                              |                  |
                                              | S3           O3  |
                                              |                  |
                                              | DI2              |  +-----------------+
                                              |                  |  |                 |
                                              | S2           CO2 +->+ CARRY_CO_DIRECT |
                                              |                  |  |                 |
                                              | DI1              |  +-----------------+
                                              |                  |
                                              | S1           O2  |
                                              |      CARRY4      |
                                              | DI0 (chained)    |  +-----------------+
                                              |                  |  |                 |
                                              | S0           CO1 +->+ CARRY_CO_DIRECT |
                                              |                  |  |                 |
                                              | CYINIT           |  +-----------------+
                                              |                  |
                         +-----------------+  |              O1  |
                         |                 |  |                  |
                      +->+ CARRY_COUT_PLUG +->+ CI               |  +-----------------+
                      |  |                 |  |                  |  |                 |
                      |  +-----------------+  |              CO0 +->+ CARRY_CO_DIRECT |
                      |                       |                  |  |                 |
                      |                       |                  |  +-----------------+
                      +-------------------+   |                  |
                                          |   |              O0  |
+------------------+  +-----------------+ |   |                  |
|                  |  |                 | |   +------------------+
|              CO3 +->+ CARRY_CO_DIRECT +-+
|                  |  |                 |
| DI3              |  +-----------------+
|                  |
| S3           O3  |
|                  |
| DI2              |  +-----------------+
|                  |  |                 |
| S2           CO2 +->+ CARRY_CO_DIRECT |
|                  |  |                 |
| DI1              |  +-----------------+
|                  |
| S1           O2  |
|       CARRY4     |
| DI0   (root)     |  +-----------------+
|                  |  |                 |
| S0           CO1 +->+ CARRY_CO_DIRECT |
|                  |  |                 |
| CYINIT           |  +-----------------+
|                  |
|              O1  |
|                  |
| CI               |  +-----------------+
|                  |  |                 |
|              CO0 +->+ CARRY_CO_DIRECT |
|                  |  |                 |
|                  |  +-----------------+
|                  |
|              O0  |
|                  |
+------------------+

Each CARRY4 spans the 4 rows of the SLICEL/SLICEM.
Row 0 is the S0/DI0/O0/CO0 ports, row 1 is S1/DI1/O1/CO1 ports, etc.

So there are five cases the script has to handle:

 - No congestion is present between O and CO ->

    Do nothing.

 - Congestion is present on rows 0-2 and row above is in use ->

    Change CARRY_CO_DIRECT to CARRY_CO_LUT.

    Routing and LUT delays are incurred in this case.

 - Congestion is present on rows 0-2 and row above is not in use ->

    Remap CO to O from the row above, and set S on the next row to 0 to
    ensure O outputs CI from the row below.

    No additional delays for this change.

 - Congestion is present on row 3 and CO3 is not connected to another CARRY ->

    Change CARRY_CO_DIRECT to CARRY_CO_TOP_POP.  This adds 1 dummy layer to
    the carry chain to output the CO.

    No additional delays for this change.

 - Congestion is present on row 3 and CO3 is connected directly to another
   CARRY4 ->

    Change CARRY_CO_DIRECT to CARRY_CO_LUT *and* change the chained
    CARRY_COUT_PLUG to be directly connected to the previous CO3.

    Routing and LUT delays are incurred in this case.

    Diagram for this case:

                                                 +-------------------+  +-----------------+
                                                 |                   |  |                 |
                                                 |               CO3 +->+ CARRY_CO_DIRECT |
                                                 |                   |  |                 |
                                                 |  DI3              |  +-----------------+
                                                 |                   |
                                                 |  S3           O3  |
                                                 |                   |
                                                 |  DI2              |  +-----------------+
                                                 |                   |  |                 |
                                                 |  S2           CO2 +->+ CARRY_CO_DIRECT |
                                                 |                   |  |                 |
                                                 |  DI1              |  +-----------------+
                                                 |                   |
                                                 |  S1           O2  |
                                                 |       CARRY4      |
                                                 |  DI0 (chained)    |  +-----------------+
                                                 |                   |  |                 |
                                                 |  S0           CO1 +->+ CARRY_CO_DIRECT |
                                                 |                   |  |                 |
                                                 |  CYINIT           |  +-----------------+
                                                 |                   |
                          +-----------------+    |               O1  |
                          |                 |    |                   |
                       +->+ CARRY_COUT_PLUG +--->+  CI               |  +-----------------+
                       |  |                 |    |                   |  |                 |
                       |  +-----------------+    |               CO0 +->+ CARRY_CO_DIRECT |
                       |                         |                   |  |                 |
+-------------------+  |  +-----------------+    |                   |  +-----------------+
|                   |  |  |                 |    |                   |
|               CO3 +--+->+ CARRY_CO_LUT    +-+  |               O0  |
|                   |     |                 | |  |                   |
|  DI3              |     +-----------------+ |  +-------------------+
|                   |                         |
|  S3           O3  |                         +------>
|                   |
|  DI2              |     +-----------------+
|                   |     |                 |
|  S2           CO2 +---->+ CARRY_CO_DIRECT |
|                   |     |                 |
|  DI1              |     +-----------------+
|                   |
|  S1           O2  |
|        CARRY4     |
|  DI0   (root)     |     +-----------------+
|                   |     |                 |
|  S0           CO1 +---->+ CARRY_CO_DIRECT |
|                   |     |                 |
|  CYINIT           |     +-----------------+
|                   |
|               O1  |
|                   |
|  CI               |     +-----------------+
|                   |     |                 |
|               CO0 +---->+ CARRY_CO_DIRECT |
|                   |     |                 |
|                   |     +-----------------+
|                   |
|               O0  |
|                   |
+-------------------+

After this script is run, clean_carry_map.v is used to convert CARRY_CO_DIRECT
into a direct connection, and CARRY_CO_LUT is mapped to a LUT to compute the
carry output.

"""

import json
from sys import stdin, stdout


def find_top_module(design):
    """
    Looks for the top-level module in the design. Returns its name. Throws
    an exception if none was found.
    """

    for name, module in design["modules"].items():
        attrs = module["attributes"]
        if "top" in attrs and int(attrs["top"]) == 1:
            return name

    raise RuntimeError("No top-level module found in the design!")


def find_carry4_chains(design, top_module, bit_to_cells):
    """Identify CARRY4 carry chains starting from the root CARRY4.

    All non-root CARRY4 cells should end up as part of a chain, otherwise
    an assertion is raised.

    Arguments:
     design (dict) - "design" field from Yosys JSON format
     top_module (str) - Name of top module.
     bit_to_cells (dict) - Map of net bit identifier and cell information.
        Computes in "create_bit_to_cell_map".

    Returns:
        list of list of strings - List of CARRY4 chains.  Each chain is a list
            of cellnames.  The cells are listed in chain order, starting from
            the root.

    """
    cells = design["modules"][top_module]["cells"]

    used_carry4s = set()
    root_carry4s = []
    nonroot_carry4s = {}
    for cellname in cells:
        cell = cells[cellname]
        if cell["type"] != "CARRY4_VPR":
            continue
        connections = cell["connections"]

        if "CIN" in connections:
            cin_connections = connections["CIN"]
            assert len(cin_connections) == 1

            # Goto driver of CIN, should be a CARRY_COUT_PLUG.
            plug_cellname, port, bit_idx = bit_to_cells[cin_connections[0]][0]
            plug_cell = cells[plug_cellname]
            assert plug_cell["type"] == "CARRY_COUT_PLUG", plug_cellname
            assert port == "COUT"

            plug_connections = plug_cell["connections"]

            cin_connections = plug_connections["CIN"]
            assert len(cin_connections) == 1

            # Goto driver of CIN, should be a CARRY_CO_DIRECT.
            direct_cellname, port, bit_idx = bit_to_cells[cin_connections[0]][0]
            direct_cell = cells[direct_cellname]
            assert direct_cell["type"] == "CARRY_CO_DIRECT", direct_cellname
            assert port == "OUT"

            direct_connections = direct_cell["connections"]

            co_connections = direct_connections["CO"]
            assert len(co_connections) == 1

            nonroot_carry4s[co_connections[0]] = cellname
        else:
            used_carry4s.add(cellname)
            root_carry4s.append(cellname)

    # Walk from each root CARRY4 to each child CARRY4 module.
    chains = []
    for cellname in root_carry4s:
        chain = [cellname]

        while True:
            # Follow CO3 to the next CARRY4, if any.
            cell = cells[cellname]
            connections = cell["connections"]

            co3_connections = connections.get("CO3", None)
            if co3_connections is None:
                # No next CARRY4, stop here.
                break

            found_next_link = False
            for connection in co3_connections:
                next_cellname = nonroot_carry4s.get(connection, None)
                if next_cellname is not None:
                    cellname = next_cellname
                    used_carry4s.add(cellname)
                    chain.append(cellname)
                    found_next_link = True
                    break

            if not found_next_link:
                break

        chains.append(chain)

    # Make sure all non-root CARRY4's got used.
    for bit, cellname in nonroot_carry4s.items():
        assert cellname in used_carry4s, (bit, cellname)

    return chains


def create_bit_to_cell_map(design, top_module):
    """Create map from net bit identifier to cell information.

    Arguments:
     design (dict) - "design" field from Yosys JSON format
     top_module (str) - Name of top module.

    Returns:
     bit_to_cells (dict) - Map of net bit identifier and cell information.

    The map keys are the net bit identifier used to mark which net a cell port
    is connected too.  The map values are a list of cell ports that are in the
    net.  The first element of the list is the driver port, and the remaining
    elements are sink ports.

    The list elements are 3-tuples with:
      cellname (str) - The name of the cell this port belongs too
      port (str) - The name of the port this element is connected too.
      bit_idx (int) - For multi bit ports, a 0-based index into the port.

    """
    bit_to_cells = {}

    cells = design["modules"][top_module]["cells"]

    for cellname in cells:
        cell = cells[cellname]
        port_directions = cell["port_directions"]
        for port, connections in cell["connections"].items():
            is_output = port_directions[port] == "output"
            for bit_idx, bit in enumerate(connections):

                list_of_cells = bit_to_cells.get(bit, None)
                if list_of_cells is None:
                    list_of_cells = [None]
                    bit_to_cells[bit] = list_of_cells

                if is_output:
                    # First element of list of cells is net driver.
                    assert list_of_cells[0] is None, (bit, list_of_cells[0], cellname)
                    list_of_cells[0] = (cellname, port, bit_idx)
                else:
                    list_of_cells.append((cellname, port, bit_idx))

    return bit_to_cells


def is_bit_used(bit_to_cells, bit):
    """Is the net bit specified used by any sinks?"""
    list_of_cells = bit_to_cells[bit]
    return len(list_of_cells) > 1


def is_bit_used_other_than_carry4_cin(design, top_module, bit, bit_to_cells):
    """Is the net bit specified used by any sinks other than a carry chain?"""
    cells = design["modules"][top_module]["cells"]
    list_of_cells = bit_to_cells[bit]
    assert len(list_of_cells) == 2, bit

    direct_cellname, port, _ = list_of_cells[1]
    direct_cell = cells[direct_cellname]
    assert direct_cell["type"] == "CARRY_CO_DIRECT"
    assert port == "CO"

    # Follow to output
    connections = direct_cell["connections"]["OUT"]
    assert len(connections) == 1

    for cellname, port, bit_idx in bit_to_cells[connections[0]][1:]:
        cell = cells[cellname]
        if cell["type"] == "CARRY_COUT_PLUG" and port == "CIN":
            continue
        else:
            return True, direct_cellname

    return False, direct_cellname


def create_bit_to_net_map(design, top_module):
    """Create map from net bit identifier to net information.

    Arguments:
     design (dict) - "design" field from Yosys JSON format
     top_module (str) - Name of top module.

    Returns:
     bit_to_nets (dict) - Map of net bit identifier to net information.
    """
    bit_to_nets = {}

    nets = design["modules"][top_module]["netnames"]

    for net in nets:
        for bit_idx, bit in enumerate(nets[net]["bits"]):
            bit_to_nets[bit] = (net, bit_idx)

    return bit_to_nets


def fixup_cin(design, top_module, bit_to_cells, co_bit, direct_cellname):
    """Move connection from CARRY_CO_LUT.OUT -> CARRY_COUT_PLUG.CIN to
    directly to preceeding CARRY4.
    """
    cells = design["modules"][top_module]["cells"]

    direct_cell = cells[direct_cellname]
    assert direct_cell["type"] == "CARRY_CO_LUT"

    # Follow to output
    connections = direct_cell["connections"]["OUT"]
    assert len(connections) == 1

    for cellname, port, bit_idx in bit_to_cells[connections[0]][1:]:
        cell = cells[cellname]
        if cell["type"] == "CARRY_COUT_PLUG" and port == "CIN":
            assert bit_idx == 0

            cells[cellname]["connections"]["CIN"][0] = co_bit


def fixup_congested_rows(design, top_module, bit_to_cells, bit_to_nets, chain):
    """Walk the specified carry chain, and identify if any outputs are congested.

    Arguments:
     design (dict) - "design" field from Yosys JSON format
     top_module (str) - Name of top module.
     bit_to_cells (dict) - Map of net bit identifier and cell information.
        Computes in "create_bit_to_cell_map".
     bit_to_nets (dict) - Map of net bit identifier to net information.
        Computes in "create_bit_to_net_map".
     chain (list of str) - List of cells in the carry chain.

    """
    cells = design["modules"][top_module]["cells"]

    O_ports = ["O0", "O1", "O2", "O3"]
    CO_ports = ["CO0", "CO1", "CO2", "CO3"]

    def check_if_rest_of_carry4_is_unused(cellname, cell_idx):
        assert cell_idx < len(O_ports)

        cell = cells[cellname]
        connections = cell["connections"]

        for o, co in zip(O_ports[cell_idx:], CO_ports[cell_idx:]):
            o_conns = connections[o]
            assert len(o_conns) == 1
            o_bit = o_conns[0]
            if is_bit_used(bit_to_cells, o_bit):
                return False

            co_conns = connections[co]
            assert len(co_conns) == 1
            co_bit = co_conns[0]
            if is_bit_used(bit_to_cells, co_bit):
                return False

        return True

    # Carry chain is congested if both O and CO is used at the same level.
    # CO to next element in the chain is fine.
    for chain_idx, cellname in enumerate(chain):
        cell = cells[cellname]
        connections = cell["connections"]
        for cell_idx, (o, co) in enumerate(zip(O_ports, CO_ports)):
            o_conns = connections[o]
            assert len(o_conns) == 1
            o_bit = o_conns[0]

            co_conns = connections[co]
            assert len(co_conns) == 1
            co_bit = co_conns[0]

            is_o_used = is_bit_used(bit_to_cells, o_bit)
            is_co_used, direct_cellname = is_bit_used_other_than_carry4_cin(design, top_module, co_bit, bit_to_cells)

            if is_o_used and is_co_used:
                # Output at this row is congested.
                direct_cell = cells[direct_cellname]

                if co == "CO3" and chain_idx == len(chain) - 1:
                    # This congestion is on the top of the carry chain,
                    # emit a dummy layer to the chain.
                    direct_cell["type"] = "CARRY_CO_TOP_POP"
                    assert int(direct_cell["parameters"]["TOP_OF_CHAIN"]) == 1
                # If this is the last CARRY4 in the chain, see if the
                # remaining part of the chain is idle.
                elif chain_idx == len(chain) - 1 and check_if_rest_of_carry4_is_unused(cellname, cell_idx + 1):

                    # Because the rest of the CARRY4 is idle, it is safe to
                    # use the next row up to output the top of the carry.
                    connections["S{}".format(cell_idx + 1)] = ["1'b0"]

                    next_o_conns = connections[O_ports[cell_idx + 1]]
                    assert len(next_o_conns) == 1
                    direct_cell["connections"]["CO"][0] = next_o_conns[0]

                    netname, bit_idx = bit_to_nets[next_o_conns[0]]
                    assert bit_idx == 0

                    # Update annotation that this net is now in use.
                    net = design["module"][top_module]["netnames"][netname]
                    assert net["attributes"].get("unused_bits", None) == "0 "
                    del net["attributes"]["unused_bits"]
                else:
                    # The previous two stragies (use another layer of carry)
                    # only work for the top of the chain.  This appears to be
                    # in the middle of the chain, so just spill it out to a
                    # LUT, and fixup the direct carry chain (if any).
                    direct_cell["type"] = "CARRY_CO_LUT"

                    fixup_cin(design, top_module, bit_to_cells, co_bit, direct_cellname)


def main(design):
    top_module = find_top_module(design)
    bit_to_cells = create_bit_to_cell_map(design, top_module)
    bit_to_nets = create_bit_to_net_map(design, top_module)
    for chain in find_carry4_chains(design, top_module, bit_to_cells):
        fixup_congested_rows(design, top_module, bit_to_cells, bit_to_nets, chain)
    return design


if __name__ == "__main__":
    json.dump(main(json.load(stdin)), stdout, indent=2)
