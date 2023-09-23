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
import os
import argparse
import pickle
from collections import OrderedDict

import lxml.etree as ET

from f4pga.aux.utils.quicklogic.pp3.data_structs import ConnectionType, Loc

from f4pga.aux.utils.quicklogic.pp3.tile_import import make_top_level_pb_type
from f4pga.aux.utils.quicklogic.pp3.tile_import import make_top_level_tile

# =============================================================================


def is_direct(connection):
    """
    Returns True if the connections spans two tiles directly. Not necessarly
    at the same location
    """

    if (
        connection.src.type == ConnectionType.TILE
        and connection.dst.type == ConnectionType.TILE
        and connection.is_direct is True
    ):
        return True

    return False


# =============================================================================


def add_segment(xml_parent, segment):
    """
    Adds a segment
    """

    segment_type = "bidir"

    # Make XML
    xml_seg = ET.SubElement(
        xml_parent,
        "segment",
        {
            "name": segment.name,
            "length": str(segment.length),
            "freq": "1.0",
            "type": segment_type,
            "Rmetal": str(segment.r_metal),
            "Cmetal": str(segment.c_metal),
        },
    )

    if segment_type == "unidir":
        ET.SubElement(xml_seg, "mux", {"name": "generic"})

    elif segment_type == "bidir":
        ET.SubElement(xml_seg, "wire_switch", {"name": "generic"})
        ET.SubElement(xml_seg, "opin_switch", {"name": "generic"})

    else:
        assert False, segment_type

    e = ET.SubElement(xml_seg, "sb", {"type": "pattern"})
    e.text = " ".join(["1" for i in range(segment.length + 1)])
    e = ET.SubElement(xml_seg, "cb", {"type": "pattern"})
    e.text = " ".join(["1" for i in range(segment.length)])


def add_switch(xml_parent, switch):
    """
    Adds a switch
    """

    xml_switch = ET.SubElement(
        xml_parent,
        "switch",
        {
            "type": switch.type,
            "name": switch.name,
            "R": str(switch.r),
            "Cin": str(switch.c_in),
            "Cout": str(switch.c_out),
            "Tdel": str(switch.t_del),
        },
    )

    if switch.type in ["mux", "tristate"]:
        xml_switch.attrib["Cinternal"] = str(switch.c_int)


def initialize_arch(xml_arch, switches, segments):
    """
    Initializes the architecture definition from scratch.
    """

    # .................................
    # Device
    xml_device = ET.SubElement(xml_arch, "device")

    ET.SubElement(
        xml_device,
        "sizing",
        {
            "R_minW_nmos": "6000.0",
            "R_minW_pmos": "18000.0",
        },
    )

    ET.SubElement(xml_device, "area", {"grid_logic_tile_area": "15000.0"})

    xml = ET.SubElement(xml_device, "chan_width_distr")
    ET.SubElement(xml, "x", {"distr": "uniform", "peak": "1.0"})
    ET.SubElement(xml, "y", {"distr": "uniform", "peak": "1.0"})

    ET.SubElement(xml_device, "connection_block", {"input_switch_name": "generic"})

    ET.SubElement(
        xml_device,
        "switch_block",
        {
            "type": "wilton",
            "fs": "3",
        },
    )

    ET.SubElement(
        xml_device,
        "default_fc",
        {
            "in_type": "frac",
            "in_val": "1.0",
            "out_type": "frac",
            "out_val": "1.0",
        },
    )

    # .................................
    # Switchlist
    xml_switchlist = ET.SubElement(xml_arch, "switchlist")
    got_generic_switch = False

    for switch in switches:
        add_switch(xml_switchlist, switch)

        # Check for the generic switch
        if switch.name == "generic":
            got_generic_switch = True

    # No generic switch
    assert got_generic_switch

    # .................................
    # Segmentlist
    xml_seglist = ET.SubElement(xml_arch, "segmentlist")

    for segment in segments:
        add_segment(xml_seglist, segment)


def write_tiles(xml_arch, arch_tile_types, tile_types, equivalent_sites):
    """
    Generates the "tiles" section of the architecture file
    """

    # The "tiles" section
    xml_tiles = xml_arch.find("tiles")
    if xml_tiles is None:
        xml_tiles = ET.SubElement(xml_arch, "tiles")

    # Add tiles
    for tile_type, sub_tiles in arch_tile_types.items():
        xml = make_top_level_tile(tile_type, sub_tiles, tile_types, equivalent_sites)

        xml_tiles.append(xml)


def write_pb_types(xml_arch, arch_pb_types, tile_types, nsmap):
    """
    Generates the "complexblocklist" section.
    """

    # Complexblocklist
    xml_cplx = xml_arch.find("complexblocklist")
    if xml_cplx is None:
        xml_cplx = ET.SubElement(xml_arch, "complexblocklist")

    # Add pb_types
    for pb_type in arch_pb_types:
        xml = make_top_level_pb_type(tile_types[pb_type], nsmap)
        xml_cplx.append(xml)


def write_models(xml_arch, arch_models, nsmap):
    """
    Generates the "models" section.
    """

    # Models
    xml_models = xml_arch.find("models")
    if xml_models is None:
        xml_models = ET.SubElement(xml_arch, "models")

    # Include cell models
    xi_include = "{{{}}}include".format(nsmap["xi"])
    for model in arch_models:
        name = model.lower()

        # Be smart. Check if there is a file for that cell in the current
        # directory. If not then use the one from "primitives" path
        model_file = "./{}.model.xml".format(name)
        if not os.path.isfile(model_file):
            model_file = "../../primitives/{}/{}.model.xml".format(name, name)

        ET.SubElement(
            xml_models,
            xi_include,
            {
                "href": model_file,
                "xpointer": "xpointer(models/child::node())",
            },
        )


def write_tilegrid(xml_arch, arch_tile_grid, loc_map, layout_name):
    """
    Generates the "layout" section of the arch XML and appends it to the
    root given.
    """

    # Remove the "layout" tag if any
    xml_layout = xml_arch.find("layout")
    if xml_layout is not None:
        xml_arch.remove(xml_layout)

    # Grid size
    xs = [flat_loc[0] for flat_loc in arch_tile_grid]
    ys = [flat_loc[1] for flat_loc in arch_tile_grid]
    w = max(xs) + 1
    h = max(ys) + 1

    # Fixed layout
    xml_layout = ET.SubElement(xml_arch, "layout")
    xml_fixed = ET.SubElement(
        xml_layout,
        "fixed_layout",
        {
            "name": layout_name,
            "width": str(w),
            "height": str(h),
        },
    )

    # Individual tiles
    for flat_loc, tile in arch_tile_grid.items():
        if tile is None:
            continue

        # Unpack
        tile_type, capacity = tile

        # Single tile
        xml_sing = ET.SubElement(
            xml_fixed,
            "single",
            {
                "type": "TL-{}".format(tile_type.upper()),
                "x": str(flat_loc[0]),
                "y": str(flat_loc[1]),
                "priority": str(10),  # Not sure if we need this
            },
        )

        # Gather metadata
        metadata = []
        for i in range(capacity):
            loc = Loc(x=flat_loc[0], y=flat_loc[1], z=i)

            if loc in loc_map.bwd:
                phy_loc = loc_map.bwd[loc]
                metadata.append("X{}Y{}".format(phy_loc.x, phy_loc.y))

        # Emit metadata if any
        if len(metadata):
            xml_metadata = ET.SubElement(xml_sing, "metadata")
            xml_meta = ET.SubElement(
                xml_metadata,
                "meta",
                {
                    "name": "fasm_prefix",
                },
            )
            xml_meta.text = " ".join(metadata)


def write_direct_connections(xml_arch, tile_grid, connections):
    """ """

    def get_tile(ep):
        """
        Retireves tile for the given connection endpoint
        """

        if ep.loc in tile_grid and tile_grid[ep.loc] is not None:
            return tile_grid[ep.loc]

        else:
            print("ERROR: No tile found for the connection endpoint", ep)
            return None

    # Remove the "directlist" tag if any
    xml_directlist = xml_arch.find("directlist")
    if xml_directlist is not None:
        xml_arch.remove(xml_directlist)

    # Make a new one
    xml_directlist = ET.SubElement(xml_arch, "directlist")

    # Populate connections
    conns = [c for c in connections if is_direct(c)]
    for connection in conns:
        src_tile = get_tile(connection.src)
        dst_tile = get_tile(connection.dst)

        if not src_tile or not dst_tile:
            continue

        src_name = "TL-{}.{}".format(src_tile.type, connection.src.pin)
        dst_name = "TL-{}.{}".format(dst_tile.type, connection.dst.pin)

        name = "{}_at_X{}Y{}Z{}_to_{}_at_X{}Y{}Z{}".format(
            src_name,
            connection.src.loc.x,
            connection.src.loc.y,
            connection.src.loc.z,
            dst_name,
            connection.dst.loc.x,
            connection.dst.loc.y,
            connection.dst.loc.z,
        )

        delta_loc = Loc(
            x=connection.dst.loc.x - connection.src.loc.x,
            y=connection.dst.loc.y - connection.src.loc.y,
            z=connection.dst.loc.z - connection.src.loc.z,
        )

        # Format the direct connection tag
        ET.SubElement(
            xml_directlist,
            "direct",
            {
                "name": name,
                "from_pin": src_name,
                "to_pin": dst_name,
                "x_offset": str(delta_loc.x),
                "y_offset": str(delta_loc.y),
                "z_offset": str(delta_loc.z),
            },
        )


# =============================================================================


def main():
    # Parse arguments
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument("--vpr-db", type=str, required=True, help="VPR database file")
    parser.add_argument("--arch-out", type=str, default="arch.xml", help="Output arch XML file (def. arch.xml)")
    parser.add_argument("--device", type=str, default="quicklogic", help="Device name for the architecture")

    args = parser.parse_args()

    xi_url = "http://www.w3.org/2001/XInclude"
    ET.register_namespace("xi", xi_url)
    nsmap = {"xi": xi_url}

    # Load data from the database
    with open(args.vpr_db, "rb") as fp:
        db = pickle.load(fp)

        loc_map = db["loc_map"]
        vpr_tile_types = db["vpr_tile_types"]
        vpr_tile_grid = db["vpr_tile_grid"]
        vpr_equivalent_sites = db["vpr_equivalent_sites"]
        segments = db["segments"]
        switches = db["switches"]
        connections = db["connections"]

    # Flatten the VPR tilegrid
    flat_tile_grid = dict()
    for vpr_loc, tile in vpr_tile_grid.items():
        flat_loc = (vpr_loc.x, vpr_loc.y)
        if flat_loc not in flat_tile_grid:
            flat_tile_grid[flat_loc] = {}

        if tile is not None:
            flat_tile_grid[flat_loc][vpr_loc.z] = tile.type

    # Create the arch tile grid and arch tile types
    arch_tile_grid = dict()
    arch_tile_types = dict()
    arch_pb_types = set()
    arch_models = set()

    for flat_loc, tiles in flat_tile_grid.items():
        if len(tiles):
            # Group identical sub-tiles together, maintain their order
            sub_tiles = OrderedDict()
            for z, tile in tiles.items():
                if tile not in sub_tiles:
                    sub_tiles[tile] = 0
                sub_tiles[tile] += 1

            # TODO: Make arch tile type name
            tile_type = tiles[0]

            # Create the tile type with sub tile types for the arch
            arch_tile_types[tile_type] = sub_tiles

            # Add each sub-tile to top-level pb_type list
            for tile in sub_tiles:
                arch_pb_types.add(tile)

            # Add each cell of a sub-tile to the model list
            for tile in sub_tiles:
                for cell_type in vpr_tile_types[tile].cells.keys():
                    arch_models.add(cell_type)

            # Add the arch tile type to the arch tile grid
            arch_tile_grid[flat_loc] = (
                tile_type,
                len(tiles),
            )

        else:
            # Add an empty location
            arch_tile_grid[flat_loc] = None

    # Initialize the arch XML if file not given
    xml_arch = ET.Element("architecture", nsmap=nsmap)
    initialize_arch(xml_arch, switches, segments)

    # Add tiles
    write_tiles(xml_arch, arch_tile_types, vpr_tile_types, vpr_equivalent_sites)
    # Add pb_types
    write_pb_types(xml_arch, arch_pb_types, vpr_tile_types, nsmap)
    # Add models
    write_models(xml_arch, arch_models, nsmap)

    # Write the tilegrid to arch
    write_tilegrid(xml_arch, arch_tile_grid, loc_map, args.device)

    # Write direct connections
    write_direct_connections(xml_arch, vpr_tile_grid, connections)

    # Save the arch
    ET.ElementTree(xml_arch).write(args.arch_out, pretty_print=True, xml_declaration=True, encoding="utf-8")


# =============================================================================

if __name__ == "__main__":
    main()
