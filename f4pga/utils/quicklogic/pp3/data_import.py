#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright (C) 2022 F4PGA Authors
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
Functions related to parsing and processing of data stored in a QuickLogic
TechFile.
"""
from copy import deepcopy
import itertools
import argparse
from collections import defaultdict
import pickle
import re
import csv

import lxml.etree as ET

from f4pga.utils.quicklogic.pp3.data_structs import (
    Pin,
    PinDirection,
    Quadrant,
    ClockCell,
    Cell,
    CellType,
    Tile,
    TileType,
    Loc,
    SwitchboxPinLoc,
    SwitchboxPinType,
    Switchbox,
    SwitchboxPin,
    SwitchConnection,
    SwitchPin,
    PackagePin,
    OPPOSITE_DIRECTION,
)
from f4pga.utils.quicklogic.pp3.utils import yield_muxes, get_loc_of_cell, find_cell_in_tile, natural_keys
from f4pga.utils.quicklogic.pp3.connections import build_connections, check_connections
from f4pga.utils.quicklogic.pp3.connections import hop_to_str, get_name_and_hop, is_regular_hop_wire

# =============================================================================

# A List of cells and their pins which are clocks. These are relevant only for
# cells modeled as pb_types in VPR and are used to determine whether an input
# pin should be of type "input"/"output" or "clock".
CLOCK_PINS = {
    "LOGIC": ("QCK",),
    "CLOCK": ("IC",),
    "GMUX": (
        "IP",
        "IC",
        "IZ",
    ),
    "RAM": (
        "CLK1_0",
        "CLK1_1",
        "CLK2_0",
        "CLK2_1",
    ),
}

# A list of const pins
CONST_PINS = (
    "GND",
    "VCC",
)

# =============================================================================


def parse_library(xml_library):
    """
    Loads cell definitions from the XML
    """

    KNOWN_PORT_ATTRIB = [
        "hardWired",
        "isInvertible",
        "isAsynchronous",
        "realPortName",
        "isblank",
        "io",
        "unet",
    ]

    cells = []

    for xml_node in xml_library:
        # Skip those
        if xml_node.tag in ["PortProperties"]:
            continue

        cell_type = xml_node.tag
        cell_pins = []

        # Load pins
        for xml_pins in itertools.chain(xml_node.findall("INPUT"), xml_node.findall("OUTPUT")):
            # Pin direction
            if xml_pins.tag == "INPUT":
                direction = PinDirection.INPUT
            elif xml_pins.tag == "OUTPUT":
                direction = PinDirection.OUTPUT
            else:
                assert False, xml_pins.tag

            # "mport"
            for xml_mport in xml_pins:
                xml_bus = xml_mport.find("bus")

                # Check if the port is routable. Skip it if it is not.
                is_routable = xml_mport.get("routable", "true") == "true"
                if not is_routable:
                    continue

                # Gather attributes
                port_attrib = {}
                for key, val in xml_mport.attrib.items():
                    if key in KNOWN_PORT_ATTRIB:
                        port_attrib[key] = str(val)

                # A bus
                if xml_bus is not None:
                    lsb = int(xml_bus.attrib["lsb"])
                    msb = int(xml_bus.attrib["msb"])
                    stp = int(xml_bus.attrib["step"])

                    for i in range(lsb, msb + 1, stp):
                        cell_pins.append(
                            Pin(
                                name="{}[{}]".format(xml_bus.attrib["name"], i),
                                direction=direction,
                                attrib=port_attrib,
                            )
                        )

                # A single pin
                else:
                    name = xml_mport.attrib["name"]

                    # HACK: Do not import the CLOCK.OP pin
                    if cell_type == "CLOCK" and name == "OP":
                        continue

                    if cell_type in CLOCK_PINS and name in CLOCK_PINS[cell_type]:
                        port_attrib["clock"] = "true"

                    cell_pins.append(
                        Pin(
                            name=name,
                            direction=direction,
                            attrib=port_attrib,
                        )
                    )

        # Add the cell
        cells.append(CellType(type=cell_type, pins=cell_pins))

    return cells


# =============================================================================


def load_logic_cells(xml_placement, cellgrid, cells_library):
    # Load "LOGIC" tiles
    xml_logic = xml_placement.find("LOGIC")
    assert xml_logic is not None

    exceptions = set()
    xml_exceptions = xml_logic.find("EXCEPTIONS")
    if xml_exceptions is not None:
        for xml in xml_exceptions:
            tag = xml.tag.upper()

            # FIXME: Is this connect decoding of those werid loc specs?
            x = 1 + ord(tag[0]) - ord("A")
            y = 1 + int(tag[1:])

            exceptions.add(Loc(x=x, y=y, z=0))

    xml_logicmatrix = xml_logic.find("LOGICMATRIX")
    assert xml_logicmatrix is not None

    x0 = int(xml_logicmatrix.get("START_COLUMN"))
    nx = int(xml_logicmatrix.get("COLUMNS"))
    y0 = int(xml_logicmatrix.get("START_ROW"))
    ny = int(xml_logicmatrix.get("ROWS"))

    for j in range(ny):
        for i in range(nx):
            loc = Loc(x0 + i, y0 + j, 0)

            if loc in exceptions:
                continue

            cell_type = "LOGIC"
            assert cell_type in cells_library, cell_type

            cellgrid[loc].append(Cell(type=cell_type, index=None, name=cell_type, alias=None))


def load_other_cells(xml_placement, cellgrid, cells_library):
    # Loop over XML entries
    for xml in xml_placement:
        # Got a "Cell" tag
        if xml.tag == "Cell":
            cell_name = xml.get("name")
            cell_type = xml.get("type")

            assert cell_type in cells_library, (
                cell_type,
                cell_name,
            )

            # Cell matrix
            xml_matrices = [x for x in xml if x.tag.startswith("Matrix")]
            for xml_matrix in xml_matrices:
                x0 = int(xml_matrix.get("START_COLUMN"))
                nx = int(xml_matrix.get("COLUMNS"))
                y0 = int(xml_matrix.get("START_ROW"))
                ny = int(xml_matrix.get("ROWS"))

                for j in range(ny):
                    for i in range(nx):
                        loc = Loc(x0 + i, y0 + j, 0)

                        cellgrid[loc].append(
                            Cell(
                                type=cell_type,
                                index=None,
                                name=cell_name,
                                alias=None,
                            )
                        )

            # A single cell
            if len(xml_matrices) == 0:
                x = int(xml.get("column"))
                y = int(xml.get("row"))

                loc = Loc(x, y, 0)
                alias = xml.get("Alias", None)

                cellgrid[loc].append(
                    Cell(
                        type=cell_type,
                        index=None,
                        name=cell_name,
                        alias=alias,
                    )
                )

        # Got something else, parse recursively
        else:
            load_other_cells(xml, cellgrid, cells_library)


def make_tile_type_name(cells):
    """
    Generate the tile type name from cell types
    """
    cell_types = sorted([c.type for c in cells])
    cell_counts = {t: 0 for t in cell_types}

    for cell in cells:
        cell_counts[cell.type] += 1

    parts = []
    for t, c in cell_counts.items():
        if c == 1:
            parts.append(t)
        else:
            parts.append("{}x{}".format(c, t))

    return "_".join(parts).upper()


def parse_placement(xml_placement, cells_library):
    # Load tilegrid quadrants
    quadrants = {}

    xml_quadrants = xml_placement.find("Quadrants")
    assert xml_quadrants is not None

    xmin = None
    xmax = None
    ymin = None
    ymax = None

    for xml_quadrant in xml_quadrants:
        name = xml_quadrant.get("name")
        x0 = int(xml_quadrant.get("ColStartNum"))
        x1 = int(xml_quadrant.get("ColEndNum"))
        y0 = int(xml_quadrant.get("RowStartNum"))
        y1 = int(xml_quadrant.get("RowEndNum"))

        quadrants[name] = Quadrant(
            name=name,
            x0=x0,
            x1=x1,
            y0=y0,
            y1=y1,
        )

        xmin = min(xmin, x0) if xmin is not None else x0
        xmax = max(xmax, x1) if xmax is not None else x1
        ymin = min(ymin, y0) if ymin is not None else y0
        ymax = max(ymax, y1) if ymax is not None else y1

    # Define the initial tile grid. Group cells with the same location
    # together.
    cellgrid = defaultdict(lambda: [])

    # Load LOGIC cells into it
    load_logic_cells(xml_placement, cellgrid, cells_library)
    # Load other cells
    load_other_cells(xml_placement, cellgrid, cells_library)

    # Assign each location with a tile type name generated basing on cells
    # present there.
    tile_types = {}
    tile_types_at_loc = {}
    for loc, cells in cellgrid.items():
        # Generate type and assign
        type = make_tile_type_name(cells)
        tile_types_at_loc[loc] = type

        # A new type? complete its definition
        if type not in tile_types:
            cell_types = [c.type for c in cells]
            cell_count = {t: len([c for c in cells if c.type == t]) for t in cell_types}

            tile_type = TileType(type, cell_count)
            tile_type.make_pins(cells_library)
            tile_types[type] = tile_type

    # Make the final tilegrid
    tilegrid = {}
    for loc, type in tile_types_at_loc.items():
        # Group cells by type
        tile_cells_by_type = defaultdict(lambda: [])
        for cell in cellgrid[loc]:
            tile_cells_by_type[cell.type].append(cell)

        # Create a list of cell instances within the tile
        tile_cells = []
        for cell_type, cell_list in tile_cells_by_type.items():
            cell_list.sort(key=lambda c: natural_keys(c.name))

            for i, cell in enumerate(cell_list):
                tile_cells.append(Cell(type=cell.type, index=i, name=cell.name, alias=cell.alias))

        tilegrid[loc] = Tile(type=type, name="TILE_X{}Y{}".format(loc.x, loc.y), cells=tile_cells)

    return quadrants, tile_types, tilegrid


def populate_switchboxes(xml_sbox, switchbox_grid):
    """
    Assings each tile in the grid its switchbox type.
    """
    xmin = int(xml_sbox.attrib["ColStartNum"])
    xmax = int(xml_sbox.attrib["ColEndNum"])
    ymin = int(xml_sbox.attrib["RowStartNum"])
    ymax = int(xml_sbox.attrib["RowEndNum"])

    for y, x in itertools.product(range(ymin, ymax + 1), range(xmin, xmax + 1)):
        loc = Loc(x, y, 0)

        assert loc not in switchbox_grid, loc
        switchbox_grid[loc] = xml_sbox.tag


# =============================================================================


def update_switchbox_pins(switchbox):
    """
    Identifies top-level inputs and outputs of the switchbox and updates lists
    of them.
    """
    switchbox.inputs = {}
    switchbox.outputs = {}

    # Top-level inputs and their locations. Indexed by pin names.
    input_locs = defaultdict(lambda: [])

    for stage_id, stage in switchbox.stages.items():
        for switch_id, switch in stage.switches.items():
            for mux_id, mux in switch.muxes.items():
                # Add the mux output pin as top level output if necessary
                if mux.output.name is not None:
                    loc = SwitchboxPinLoc(
                        stage_id=stage.id,
                        switch_id=switch.id,
                        mux_id=mux.id,
                        pin_id=0,
                        pin_direction=PinDirection.OUTPUT,
                    )

                    if stage.type == "STREET":
                        pin_type = SwitchboxPinType.LOCAL
                    else:
                        pin_type = SwitchboxPinType.HOP

                    pin = SwitchboxPin(
                        id=len(switchbox.outputs),
                        name=mux.output.name,
                        direction=PinDirection.OUTPUT,
                        locs=[loc],
                        type=pin_type,
                    )

                    assert pin.name not in switchbox.outputs, pin
                    switchbox.outputs[pin.name] = pin

                # Add the mux input pins as top level inputs if necessary
                for pin in mux.inputs.values():
                    if pin.name is not None:
                        loc = SwitchboxPinLoc(
                            stage_id=stage.id,
                            switch_id=switch.id,
                            mux_id=mux.id,
                            pin_id=pin.id,
                            pin_direction=PinDirection.INPUT,
                        )

                        input_locs[pin.name].append(loc)

    # Add top-level input pins to the switchbox.
    keys = sorted(input_locs.keys(), key=lambda k: k[0])
    for name, locs in {k: input_locs[k] for k in keys}.items():
        # Determine the pin type
        is_hop = is_regular_hop_wire(name)
        _, hop = get_name_and_hop(name)

        if name in ["VCC", "GND"]:
            pin_type = SwitchboxPinType.CONST
        elif name.startswith("CAND"):
            pin_type = SwitchboxPinType.GCLK
        elif is_hop:
            pin_type = SwitchboxPinType.HOP
        elif hop is not None:
            pin_type = SwitchboxPinType.FOREIGN
        else:
            pin_type = SwitchboxPinType.LOCAL

        pin = SwitchboxPin(id=len(switchbox.inputs), name=name, direction=PinDirection.INPUT, locs=locs, type=pin_type)

        assert pin.name not in switchbox.inputs, pin
        switchbox.inputs[pin.name] = pin

    return switchbox


def parse_switchbox(xml_sbox, xml_common=None):
    """
    Parses the switchbox definition from XML. Returns a Switchbox object
    """
    switchbox = Switchbox(type=xml_sbox.tag)

    # Identify stages. Append stages from the "COMMON_STAGES" section if
    # given.
    stages = [n for n in xml_sbox if n.tag.startswith("STAGE")]

    if xml_common is not None:
        common_stages = [n for n in xml_common if n.tag.startswith("STAGE")]
        stages.extend(common_stages)

    # Load stages
    for xml_stage in stages:
        # Get stage id
        stage_id = int(xml_stage.attrib["StageNumber"])
        assert stage_id not in switchbox.stages, (stage_id, switchbox.stages.keys())

        stage_type = xml_stage.attrib["StageType"]

        # Add the new stage
        stage = Switchbox.Stage(id=stage_id, type=stage_type)
        switchbox.stages[stage_id] = stage

        # Process outputs
        switches = {}
        for xml_output in xml_stage.findall("Output"):
            out_switch_id = int(xml_output.attrib["SwitchNum"])
            out_pin_id = int(xml_output.attrib["SwitchOutputNum"])
            out_pin_name = xml_output.get("JointOutputName", None)

            # These indicate unconnected top-level output.
            if out_pin_name in ["-1"]:
                out_pin_name = None

            # Add a new switch if needed
            if out_switch_id not in switches:
                switches[out_switch_id] = Switchbox.Switch(out_switch_id, stage_id)
            switch = switches[out_switch_id]

            # Add a mux for the output
            mux = Switchbox.Mux(out_pin_id, switch.id)
            assert mux.id not in switch.muxes, mux
            switch.muxes[mux.id] = mux

            # Add output pin to the mux
            mux.output = SwitchPin(id=0, name=out_pin_name, direction=PinDirection.OUTPUT)

            # Process inputs
            for xml_input in xml_output:
                inp_pin_id = int(xml_input.tag.replace("Input", ""))
                inp_pin_name = xml_input.get("WireName", None)
                inp_hop_dir = xml_input.get("Direction", None)
                inp_hop_len = int(xml_input.get("Length", "-1"))

                # These indicate unconnected top-level input.
                if inp_pin_name in ["-1"]:
                    inp_pin_name = None

                # Append the actual wire length and hop diretion to names of
                # pins that connect to HOP wires.
                is_hop = inp_hop_dir in ["Left", "Right", "Top", "Bottom"]
                if is_hop:
                    inp_pin_name = "{}_{}{}".format(inp_pin_name, inp_hop_dir[0], inp_hop_len)

                # Add the input to the mux
                pin = SwitchPin(id=inp_pin_id, name=inp_pin_name, direction=PinDirection.INPUT)

                assert pin.id not in mux.inputs, pin
                mux.inputs[pin.id] = pin

                # Add internal connection
                if stage_type == "STREET" and stage_id > 0:
                    conn_stage_id = int(xml_input.attrib["Stage"])
                    conn_switch_id = int(xml_input.attrib["SwitchNum"])
                    conn_pin_id = int(xml_input.attrib["SwitchOutputNum"])

                    conn = SwitchConnection(
                        src=SwitchboxPinLoc(
                            stage_id=conn_stage_id,
                            switch_id=conn_switch_id,
                            mux_id=conn_pin_id,
                            pin_id=0,
                            pin_direction=PinDirection.OUTPUT,
                        ),
                        dst=SwitchboxPinLoc(
                            stage_id=stage.id,
                            switch_id=switch.id,
                            mux_id=mux.id,
                            pin_id=inp_pin_id,
                            pin_direction=PinDirection.INPUT,
                        ),
                    )

                    assert conn not in switchbox.connections, conn
                    switchbox.connections.add(conn)

        # Add switches to the stage
        stage.switches = switches

    # Update top-level pins
    update_switchbox_pins(switchbox)

    return switchbox


# =============================================================================


def parse_wire_mapping_table(xml_root, switchbox_grid, switchbox_types):
    """
    Parses the "DeviceWireMappingTable" section. Returns a dict indexed by
    locations.
    """

    def yield_locs_and_maps():
        """
        Yields locations and wire mappings associated with it.
        """
        RE_LOC = re.compile(r"^(Row|Col)_([0-9]+)_([0-9]+)$")

        # Rows
        xml_rows = [e for e in xml_root if e.tag.startswith("Row_")]
        for xml_row in xml_rows:
            # Decode row range
            match = RE_LOC.match(xml_row.tag)
            assert match is not None, xml_row.tag

            row_beg = int(xml_row.attrib["RowStartNum"])
            row_end = int(xml_row.attrib["RowEndNum"])

            assert row_beg == int(match.group(2)), (xml_row.tag, row_beg, row_end)
            assert row_end == int(match.group(3)), (xml_row.tag, row_beg, row_end)

            # Columns
            xml_cols = [e for e in xml_row if e.tag.startswith("Col_")]
            for xml_col in xml_cols:
                # Decode column range
                match = RE_LOC.match(xml_col.tag)
                assert match is not None, xml_col.tag

                col_beg = int(xml_col.attrib["ColStartNum"])
                col_end = int(xml_col.attrib["ColEndNum"])

                assert col_beg == int(match.group(2)), (xml_col.tag, col_beg, col_end)
                assert col_end == int(match.group(3)), (xml_col.tag, col_beg, col_end)

                # Wire maps
                xml_maps = [e for e in xml_col if e.tag.startswith("Stage_")]

                # Yield wire maps for each location
                for y in range(row_beg, row_end + 1):
                    for x in range(col_beg, col_end + 1):
                        yield (Loc(x=x, y=y, z=0), xml_maps)

    # Process wire maps
    wire_maps = defaultdict(lambda: {})

    RE_STAGE = re.compile(r"^Stage_([0-9])$")
    RE_JOINT = re.compile(r"^Join\.([0-9]+)\.([0-9]+)\.([0-9]+)$")
    RE_WIREMAP = re.compile(r"^WireMap\.(Top|Bottom|Left|Right)\.Length_([0-9])\.(.*)$")

    for loc, xml_maps in yield_locs_and_maps():
        for xml_map in xml_maps:
            # Decode stage id
            match = RE_STAGE.match(xml_map.tag)
            assert match is not None, xml_map.tag

            stage_id = int(xml_map.attrib["StageNumber"])
            assert stage_id == int(match.group(1)), (xml_map.tag, stage_id)

            # Decode wire joints
            joints = {k: v for k, v in xml_map.attrib.items() if k.startswith("Join.")}
            for joint_key, joint_map in joints.items():
                # Decode the joint key
                match = RE_JOINT.match(joint_key)
                assert match is not None, joint_key

                pin_loc = SwitchboxPinLoc(
                    stage_id=stage_id,
                    switch_id=int(match.group(1)),
                    mux_id=int(match.group(2)),
                    pin_id=int(match.group(3)),
                    pin_direction=PinDirection.INPUT,  # FIXME: Are those always inputs ?
                )

                # Decode the wire name
                match = RE_WIREMAP.match(joint_map)
                assert match is not None, joint_map

                wire_hop_dir = match.group(1)
                wire_hop_len = int(match.group(2))
                wire_name = match.group(3)

                # Compute location of the tile that the wire is connected to
                if wire_hop_dir == "Top":
                    tile_loc = Loc(x=loc.x, y=loc.y - wire_hop_len, z=0)
                elif wire_hop_dir == "Bottom":
                    tile_loc = Loc(x=loc.x, y=loc.y + wire_hop_len, z=0)
                elif wire_hop_dir == "Left":
                    tile_loc = Loc(x=loc.x - wire_hop_len, y=loc.y, z=0)
                elif wire_hop_dir == "Right":
                    tile_loc = Loc(x=loc.x + wire_hop_len, y=loc.y, z=0)
                else:
                    assert False, wire_hop_dir

                # Append to the map
                wire_maps[loc][pin_loc] = (wire_name, tile_loc)

    return wire_maps


def parse_port_mapping_table(xml_root, switchbox_grid):
    """
    Parses switchbox port mapping tables. Returns a dict indexed by locations
    containing a dict with switchbox port to tile port name correspondence.
    """
    port_maps = defaultdict(lambda: {})

    # Sections are named "*_Table"
    xml_tables = [e for e in xml_root if e.tag.endswith("_Table")]
    for xml_table in xml_tables:
        # Get the origin
        origin = xml_table.tag.split("_")[0]
        assert origin in ["Left", "Right", "Top", "Bottom"], origin

        # Get switchbox types affected by the mapping
        sbox_types_xml = xml_table.find("SBoxTypes")
        assert sbox_types_xml is not None
        switchbox_types = set([v for k, v in sbox_types_xml.attrib.items() if k.startswith("type")])

        # Get their locations
        locs = [loc for loc, type in switchbox_grid.items() if type in switchbox_types]

        # Get the first occurrence of a switchbox with one of considered types
        # that is closes to the (0, 0) according to manhattan distance.
        base_loc = None
        for loc in locs:
            if not base_loc:
                base_loc = loc
            elif (loc.x + loc.y) < (base_loc.x + base_loc.y):
                base_loc = loc

        # Parse the port mapping table(s)
        for port_mapping_xml in xml_table.findall("PortMappingTable"):
            # Get the direction of the switchbox offset
            orientation = port_mapping_xml.attrib["Orientation"]
            if orientation == "Horizontal":
                assert origin in ["Top", "Bottom"], (origin, orientation)
                dx, dy = (+1, 0)
            elif orientation == "Vertical":
                assert origin in ["Left", "Right"], (origin, orientation)
                dx, dy = (0, +1)

            # Process the mapping of switchbox output ports
            for index_xml in port_mapping_xml.findall("Index"):
                pin_name = index_xml.attrib["Mapped_Interface_Name"]
                output_num = index_xml.attrib["SwitchOutputNum"]

                # Skip this index - empty switchbox
                if pin_name == "-1":
                    continue

                # Determine the mapped port direction
                if output_num == "-1":
                    pin_direction = PinDirection.INPUT
                else:
                    pin_direction = PinDirection.OUTPUT

                sbox_xmls = [e for e in index_xml if e.tag.startswith("SBox")]
                for sbox_xml in sbox_xmls:
                    offset = int(sbox_xml.attrib["Offset"])
                    mapped_name = sbox_xml.get("MTB_PortName", None)

                    # "-1" means unconnected
                    if mapped_name == "-1":
                        mapped_name = None

                    # Get the location for the map
                    loc = Loc(x=base_loc.x + dx * offset, y=base_loc.y + dy * offset, z=0)

                    # Append mapping
                    key = (pin_name, pin_direction)
                    assert key not in port_maps[loc], (loc, key)

                    port_maps[loc][key] = mapped_name

    # Make a normal dict
    port_maps = dict(port_maps)

    return port_maps


# =============================================================================


def parse_clock_network(xml_clock_network):
    """
    Parses the "CLOCK_NETWORK" section of the techfile
    """

    def parse_cell(xml_cell, quadrant=None):
        """
        Parses a "Cell" tag inside "CLOCK_NETWORK"
        """
        NON_PIN_TAGS = ("name", "type", "row", "column")

        cell_loc = Loc(x=int(xml_cell.attrib["column"]), y=int(xml_cell.attrib["row"]), z=0)

        # Get the cell's pinmap
        pin_map = {k: v for k, v in xml_cell.attrib.items() if k not in NON_PIN_TAGS}

        # Return the cell
        return ClockCell(
            type=xml_cell.attrib["type"], name=xml_cell.attrib["name"], loc=cell_loc, quadrant=quadrant, pin_map=pin_map
        )

    clock_cells = {}

    # Parse GMUX cells
    xml_gmux = xml_clock_network.find("GMUX")
    assert xml_gmux is not None

    for xml_cell in xml_gmux.findall("Cell"):
        clock_cell = parse_cell(xml_cell)
        clock_cells[clock_cell.name] = clock_cell

    # Parse QMUX cells
    xml_qmux = xml_clock_network.find("QMUX")
    assert xml_qmux is not None

    for xml_quad in xml_qmux:
        for xml_cell in xml_quad.findall("Cell"):
            clock_cell = parse_cell(xml_cell, xml_quad.tag)
            clock_cells[clock_cell.name] = clock_cell

    # Parse CAND cells
    xml_cand = xml_clock_network.find("COL_CLKEN")
    assert xml_cand is not None

    for xml_quad in xml_cand:
        for xml_cell in xml_quad.findall("Cell"):
            clock_cell = parse_cell(xml_cell, xml_quad.tag)
            clock_cells[clock_cell.name] = clock_cell

    # Since we are not going to use dynamic enables on CAND we remove the EN
    # pin connection from the pinmap. This way the connections between
    # switchboxes which drive them can be used for generic routing.
    for cell_name in clock_cells.keys():
        cell = clock_cells[cell_name]
        pin_map = cell.pin_map

        if cell.type == "CAND" and "EN" in pin_map:
            del pin_map["EN"]

        clock_cells[cell_name] = ClockCell(
            name=cell.name, type=cell.type, loc=cell.loc, quadrant=cell.quadrant, pin_map=pin_map
        )

    return clock_cells


def populate_clk_mux_port_maps(port_maps, clock_cells, tile_grid, cells_library):
    """
    Converts global clock network cells port mappings and appends them to
    the port_maps used later for switchbox specialization.
    """

    for clock_cell in clock_cells.values():
        cell_type = clock_cell.type
        loc = clock_cell.loc

        # Find the cell in the cells_library to get its pin definitions
        assert cell_type in cells_library, cell_type
        cell_pins = cells_library[cell_type].pins

        # Find the cell in a tile
        tile = tile_grid[loc]
        cell = find_cell_in_tile(clock_cell.name, tile)

        # Add the mux location to the port map
        if loc not in port_maps:
            port_maps[loc] = {}

        # Add map entries
        for mux_pin_name, sbox_pin_name in clock_cell.pin_map.items():
            # Get the pin definition to get its driection.
            cell_pin = [p for p in cell_pins if p.name == mux_pin_name]
            assert len(cell_pin) == 1, (clock_cell, mux_pin_name)
            cell_pin = cell_pin[0]

            # Skip hard-wired pins
            if cell_pin.attrib.get("hardWired", None) == "true":
                continue

            # Add entry to the map
            key = (sbox_pin_name, OPPOSITE_DIRECTION[cell_pin.direction])

            assert key not in port_maps[loc], (port_maps[loc], key)
            port_maps[loc][key] = "{}{}_{}".format(cell.type, cell.index, mux_pin_name)


# =============================================================================


def specialize_switchboxes_with_port_maps(switchbox_types, switchbox_grid, port_maps):
    """
    Specializes switchboxes by applying port mapping.
    """

    for loc, port_map in port_maps.items():
        # No switchbox at that location
        if loc not in switchbox_grid:
            continue

        # Get the switchbox type
        switchbox_type = switchbox_grid[loc]
        switchbox = switchbox_types[switchbox_type]

        # Make a copy of the switchbox
        suffix = "X{}Y{}".format(loc.x, loc.y)
        if not switchbox.type.endswith(suffix):
            new_type = "{}_{}".format(switchbox.type, suffix)
        else:
            new_type = switchbox_type
        new_switchbox = Switchbox(new_type)
        new_switchbox.stages = deepcopy(switchbox.stages)
        new_switchbox.connections = deepcopy(switchbox.connections)

        # Remap pin names
        did_remap = False
        for stage, switch, mux in yield_muxes(new_switchbox):
            # Remap output
            alt_name = "{}.{}.{}".format(stage.id, switch.id, mux.id)

            pin = mux.output
            keys = ((pin.name, pin.direction), (alt_name, pin.direction))

            for key in keys:
                if key in port_map:
                    did_remap = True
                    mux.output = SwitchPin(
                        id=pin.id,
                        name=port_map[key],
                        direction=pin.direction,
                    )
                    break

            # Remap inputs
            for pin in mux.inputs.values():
                key = (pin.name, pin.direction)
                if key in port_map:
                    did_remap = True
                    mux.inputs[pin.id] = SwitchPin(
                        id=pin.id,
                        name=port_map[key],
                        direction=pin.direction,
                    )

        # Nothing remapped, discard the new switchbox
        if not did_remap:
            continue

        # Update top-level pins
        update_switchbox_pins(new_switchbox)

        # Add to the switchbox types and the grid
        switchbox_types[new_switchbox.type] = new_switchbox
        switchbox_grid[loc] = new_switchbox.type


def specialize_switchboxes_with_wire_maps(switchbox_types, switchbox_grid, port_maps, wire_maps):
    """
    Specializes switchboxes by applying wire mapping.
    """

    for loc, wire_map in wire_maps.items():
        # No switchbox at that location
        if loc not in switchbox_grid:
            continue

        # Get the switchbox type
        switchbox_type = switchbox_grid[loc]
        switchbox = switchbox_types[switchbox_type]

        # Make a copy of the switchbox
        suffix = "X{}Y{}".format(loc.x, loc.y)
        if not switchbox.type.endswith(suffix):
            new_type = "{}_{}".format(switchbox.type, suffix)
        else:
            new_type = switchbox_type
        new_switchbox = Switchbox(new_type)
        new_switchbox.stages = deepcopy(switchbox.stages)
        new_switchbox.connections = deepcopy(switchbox.connections)

        # Remap pin names
        did_remap = False
        for pin_loc, (wire_name, map_loc) in wire_map.items():
            # Get port map at the destination location of the wire that is
            # being remapped.
            assert map_loc in port_maps, (map_loc, wire_name)
            port_map = port_maps[map_loc]

            # Get the actual tile pin name
            key = (wire_name, PinDirection.INPUT)
            assert key in port_map, (map_loc, key)
            pin_name = port_map[key]

            # Append the hop to the wire name. Only if the map indicates that
            # the pin is connected.
            if pin_name is not None:
                hop = (
                    map_loc.x - loc.x,
                    map_loc.y - loc.y,
                )
                pin_name += "_{}".format(hop_to_str(hop))

            # Rename pin
            stage = new_switchbox.stages[pin_loc.stage_id]
            switch = stage.switches[pin_loc.switch_id]
            mux = switch.muxes[pin_loc.mux_id]
            pin = mux.inputs[pin_loc.pin_id]

            new_pin = SwitchPin(id=pin.id, direction=pin.direction, name=pin_name)

            mux.inputs[new_pin.id] = new_pin
            did_remap = True

        # Nothing remapped, discard the new switchbox
        if not did_remap:
            continue

        # Update top-level pins
        update_switchbox_pins(new_switchbox)

        # Add to the switchbox types and the grid
        switchbox_types[new_switchbox.type] = new_switchbox
        switchbox_grid[loc] = new_switchbox.type


# =============================================================================


def find_special_cells(tile_grid):
    """
    Finds cells that occupy more than one tilegrid location.
    """
    cells = {}

    # Assign each cell name its locations.
    for loc, tile in tile_grid.items():
        for cell_type, cell_names in tile.cell_names.items():
            for (cell_name,) in cell_names:
                # Skip LOGIC as it is always contained in a single tile
                if cell_name == "LOGIC":
                    continue

                if cell_name not in cells:
                    cells[cell_name] = {"type": cell_type, "locs": [loc]}
                else:
                    cells[cell_name]["locs"].append(loc)

    # Leave only those that have more than one location
    cells = {k: v for k, v in cells.items() if len(v["locs"]) > 1}


def parse_pinmap(xml_root, tile_grid):
    """
    Parses the "Package" section that holds IO pin to BIDIR/CLOCK cell map.

    Returns a dict indexed by package name which holds dicts indexed by logical
    pin names (eg. "FBIO_1"). Then, for each logical pin name there is a list
    of PackagePin objects.
    """
    pin_map = {}

    # Parse "PACKAGE" sections.
    for xml_package in xml_root.findall("PACKAGE"):
        # Initialize map
        pkg_name = xml_package.attrib["name"]
        pkg_pin_map = defaultdict(lambda: set())

        xml_pins = xml_package.find("Pins")
        assert xml_pins is not None

        # Parse pins
        for xml_pin in xml_pins.findall("Pin"):
            pin_name = xml_pin.attrib["name"]
            pin_alias = xml_pin.get("alias", None)
            cell_names = []
            cell_locs = []

            # Parse cells
            for xml_cell in xml_pin.findall("cell"):
                cell_name = xml_cell.attrib["name"]
                cell_loc = get_loc_of_cell(cell_name, tile_grid)
                if cell_loc is None:
                    continue
                cell_names.append(cell_name)
                cell_locs.append(cell_loc)

            # Location not found
            if not cell_locs:
                print("WARNING: No locs for package pin '{}' of package '{}'".format(pin_name, pkg_name))
                continue

            # Add the pin mapping
            for cell_name, cell_loc in zip(cell_names, cell_locs):
                # Find the cell
                if cell_loc not in tile_grid:
                    print("WARNING: No tile for package pin '{}' at '{}'".format(pin_name, cell_loc))
                    continue
                tile = tile_grid[cell_loc]

                cell = find_cell_in_tile(cell_name, tile)
                if cell is None:
                    print(
                        "WARNING: No cell in tile '{}' for package pin '{}' at '{}'".format(
                            tile.name, pin_name, cell_loc
                        )
                    )
                    continue

                # Store the mapping
                pkg_pin_map[pin_name].add(PackagePin(name=pin_name, alias=pin_alias, loc=cell_loc, cell=cell))

                # Check if there is a CLOCK cell at the same location
                cells = [c for c in tile.cells if c.type == "CLOCK"]
                if len(cells):
                    assert len(cells) == 1, cells

                    # Store the mapping for the CLOCK cell
                    pkg_pin_map[pin_name].add(PackagePin(name=pin_name, alias=pin_alias, loc=cell_loc, cell=cells[0]))

            # Convert to list
            pkg_pin_map[pin_name] = list(pkg_pin_map[pin_name])

        # Convert to a regular dict
        pin_map[pkg_name] = dict(**pkg_pin_map)

    return pin_map


# =============================================================================


def import_data(xml_root):
    """
    Imports the Quicklogic FPGA tilegrid and routing data from the given
    XML tree
    """

    # Get the "Library" section
    xml_library = xml_root.find("Library")
    assert xml_library is not None

    # Import cells from the library
    cells = parse_library(xml_library)

    # Get the "Placement" section
    xml_placement = xml_root.find("Placement")
    assert xml_placement is not None

    cells_library = {cell.type: cell for cell in cells}
    quadrants, tile_types, tile_grid = parse_placement(xml_placement, cells_library)

    # Import global clock network definition
    xml_clock_network = xml_placement.find("CLOCK_NETWORK")
    assert xml_clock_network is not None

    clock_cells = parse_clock_network(xml_clock_network)

    # Get the "Routing" section
    xml_routing = xml_root.find("Routing")
    assert xml_routing is not None

    # Import switchboxes
    switchbox_grid = {}
    switchbox_types = {}
    for xml_node in xml_routing:
        # Not a switchbox
        if not xml_node.tag.endswith("_SBOX"):
            continue

        # Load all "variants" of the switchbox
        xml_common = xml_node.find("COMMON_STAGES")
        for xml_sbox in xml_node:
            if xml_sbox != xml_common:
                # Parse the switchbox definition
                switchbox = parse_switchbox(xml_sbox, xml_common)

                assert switchbox.type not in switchbox_types, switchbox.type
                switchbox_types[switchbox.type] = switchbox

                # Populate switchboxes onto the tilegrid
                populate_switchboxes(xml_sbox, switchbox_grid)

    # Get the "DeviceWireMappingTable" section
    xml_wiremap = xml_routing.find("DeviceWireMappingTable")

    if xml_wiremap is not None:
        # Import wire mapping
        wire_maps = parse_wire_mapping_table(xml_wiremap, switchbox_grid, switchbox_types)

    # Get the "DevicePortMappingTable" section
    xml_portmap = xml_routing.find("DevicePortMappingTable")
    assert xml_portmap is not None

    # Import switchbox port mapping
    port_maps = parse_port_mapping_table(xml_portmap, switchbox_grid)

    # Supply port mapping table with global clock mux map
    populate_clk_mux_port_maps(port_maps, clock_cells, tile_grid, cells_library)

    if xml_wiremap is not None:
        # Specialize switchboxes with wire maps
        specialize_switchboxes_with_wire_maps(switchbox_types, switchbox_grid, port_maps, wire_maps)

    # Specialize switchboxes with local port maps
    specialize_switchboxes_with_port_maps(switchbox_types, switchbox_grid, port_maps)

    # Remove switchbox types not present in the grid anymore due to their
    # specialization.
    for type in list(switchbox_types.keys()):
        if type not in switchbox_grid.values():
            del switchbox_types[type]

    # Get the "Packages" section
    xml_packages = xml_root.find("Packages")
    assert xml_packages is not None

    # Import BIDIR cell names to package pin mapping
    package_pinmaps = parse_pinmap(xml_packages, tile_grid)

    return {
        "quadrants": quadrants,
        "cells_library": cells_library,
        "tile_types": tile_types,
        "tile_grid": tile_grid,
        "switchbox_types": switchbox_types,
        "switchbox_grid": switchbox_grid,
        "clock_cells": clock_cells,
        "package_pinmaps": package_pinmaps,
    }


# =============================================================================


def import_routing_timing(csv_file):
    """
    Reads and parses switchbox delay data from the CSV file. Returns a tree of
    dicts indexed by:
        [switchbox_type][stage_id][switch_id][mux_id][pin_id][num_inputs].

    The last dict holds tuples with rise and fall delays. Delay values are
    expressed in [ns].
    """

    # Read and parse CSV
    with open(csv_file, "r") as fp:
        # Read the first line, it should specify timing units
        line = fp.readline()
        line = line.strip().split(",")

        assert len(line) >= 3, line
        assert line[0] == "unit", line[0]

        # FIXME: For now support "ns" only
        assert line[2] == "ns", line[2]
        scale = 1.0  # Set the timing scale to 1ns

        # Read the rest of the timing data
        data = [r for r in csv.DictReader(fp)]

        # Try to guess whether the stage/switch/mux indexing starts from 0 or 1
        stage_ofs = min([int(t["Stage_Num"]) for t in data])
        switch_ofs = min([int(t["Switch_Num"]) for t in data])
        mux_ofs = min([int(t["Output_Num"]) for t in data])
        pin_ofs = min([int(t["Input_Num"]) for t in data])

        # Reformat
        switchbox_timings = {}
        for timing in data:
            # Switchbox type
            switchbox_type = timing["SBox_Type"]
            if switchbox_type not in switchbox_timings:
                switchbox_timings[switchbox_type] = {}

            # Stage id
            stage_timings = switchbox_timings[switchbox_type]
            stage_id = int(timing["Stage_Num"]) - stage_ofs
            if stage_id not in stage_timings:
                stage_timings[stage_id] = {}

            # Switch id
            switch_timings = stage_timings[stage_id]
            switch_id = int(timing["Switch_Num"]) - switch_ofs
            if switch_id not in switch_timings:
                switch_timings[switch_id] = {}

            # Mux id
            mux_timings = switch_timings[switch_id]
            mux_id = int(timing["Output_Num"]) - mux_ofs
            if mux_id not in mux_timings:
                mux_timings[mux_id] = {}

            # Mux route (edge), correspond to its input pin id.
            edge_timings = mux_timings[mux_id]
            pin_id = int(timing["Input_Num"]) - pin_ofs
            if pin_id not in edge_timings:
                edge_timings[pin_id] = {}

            # Load count and delays. Apply scaling so the timing is expressed
            # always is nanoseconds.
            edge_timing = edge_timings[pin_id]
            num_loads = int(timing["Num_Loads"])
            rise_delay = float(timing["Rise_Delay"]) * scale
            fall_delay = float(timing["Fall_Delay"]) * scale

            edge_timing[num_loads] = (rise_delay, fall_delay)

    return switchbox_timings


# =============================================================================


def main():
    # Parse arguments
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument("--techfile", type=str, required=True, help="Quicklogic 'TechFile' XML file")
    parser.add_argument("--routing-timing", type=str, default=None, help="Quicklogic routing delay CSV file")
    parser.add_argument(
        "--db", type=str, default="phy_database.pickle", help="Device name for the parsed 'database' file"
    )

    args = parser.parse_args()

    # Read and parse the XML techfile
    xml_tree = ET.parse(args.techfile)
    xml_techfile = xml_tree.getroot()

    # Load data from the techfile
    data = import_data(xml_techfile)

    # Build the connection map
    connections = build_connections(
        data["tile_types"],
        data["tile_grid"],
        data["switchbox_types"],
        data["switchbox_grid"],
        data["clock_cells"],
    )

    check_connections(connections)

    # Load timing data if given
    if args.routing_timing is not None:
        switchbox_timing = import_routing_timing(args.routing_timing)
    else:
        switchbox_timing = None

    # Prepare the database
    db_root = {
        "phy_quadrants": data["quadrants"],
        "cells_library": data["cells_library"],
        "tile_types": data["tile_types"],
        "phy_tile_grid": data["tile_grid"],
        "phy_clock_cells": data["clock_cells"],
        "switchbox_types": data["switchbox_types"],
        "switchbox_grid": data["switchbox_grid"],
        "connections": connections,
        "package_pinmaps": data["package_pinmaps"],
    }

    if switchbox_timing is not None:
        db_root["switchbox_timing"] = switchbox_timing

    # FIXME: Use something more platform-independent than pickle.
    with open(args.db, "wb") as fp:
        pickle.dump(db_root, fp, protocol=3)


# =============================================================================

if __name__ == "__main__":
    main()
