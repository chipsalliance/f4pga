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
import re
import itertools
from collections import defaultdict

import lxml.etree as ET

from f4pga.utils.quicklogic.pp3.data_structs import PinDirection
from f4pga.utils.quicklogic.pp3.utils import fixup_pin_name, get_pin_name

# =============================================================================


def add_ports(xml_parent, pins, buses=True):
    """
    Adds ports to the tile/pb_type tag. Also returns the pins grouped by
    direction and into buses. When the parameter buses is set to False then
    each bus is split into individual signals.
    """

    # Group pins into buses
    pinlists = {
        "input": defaultdict(lambda: 0),
        "output": defaultdict(lambda: 0),
        "clock": defaultdict(lambda: 0),
    }

    for pin in pins:
        if pin.direction == PinDirection.INPUT:
            if pin.attrib.get("clock", None) == "true":
                pinlist = pinlists["clock"]
            else:
                pinlist = pinlists["input"]
        elif pin.direction == PinDirection.OUTPUT:
            pinlist = pinlists["output"]
        else:
            assert False, pin

        if buses:
            name, idx = get_pin_name(pin.name)
            if idx is None:
                pinlist[name] = 1
            else:
                pinlist[name] = max(pinlist[name], idx + 1)
        else:
            name = fixup_pin_name(pin.name)
            pinlist[name] = 1

    # Generate the pinout
    for tag, pinlist in pinlists.items():
        for pin, count in pinlist.items():
            ET.SubElement(xml_parent, tag, {"name": pin, "num_pins": str(count)})

    return pinlists


# =============================================================================


def make_top_level_pb_type(tile_type, nsmap):
    """
    Generates top-level pb_type wrapper for cells of a given tile type.
    """
    pb_name = "PB-{}".format(tile_type.type.upper())
    xml_pb = ET.Element("pb_type", {"name": pb_name}, nsmap=nsmap)

    # Ports
    add_ports(xml_pb, tile_type.pins, buses=False)

    # Include cells
    xi_include = "{{{}}}include".format(nsmap["xi"])
    for cell_type, cell_count in tile_type.cells.items():
        xml_sub = ET.SubElement(xml_pb, "pb_type", {"name": cell_type.upper(), "num_pb": str(cell_count)})

        name = cell_type.lower()

        # Be smart. Check if there is a file for that cell in the current
        # directory. If not then use the one from "primitives" path
        pb_type_file = "./{}.pb_type.xml".format(name)
        if not os.path.isfile(pb_type_file):
            pb_type_file = "../../primitives/{}/{}.pb_type.xml".format(name, name)

        ET.SubElement(
            xml_sub,
            xi_include,
            {
                "href": pb_type_file,
                "xpointer": "xpointer(pb_type/child::node())",
            },
        )

    def tile_pin_to_cell_pin(name):
        match = re.match(r"^([A-Za-z_]+)([0-9]+)_(.*)$", name)
        assert match is not None, name

        return "{}[{}].{}".format(match.group(1), match.group(2), match.group(3))

    # Generate the interconnect
    xml_ic = ET.SubElement(xml_pb, "interconnect")

    for pin in tile_type.pins:
        name, idx = get_pin_name(pin.name)

        if tile_type.fake_const_pin and name == "FAKE_CONST":
            continue

        cell_pin = name if idx is None else "{}[{}]".format(name, idx)
        tile_pin = fixup_pin_name(pin.name)

        cell_pin = tile_pin_to_cell_pin(cell_pin)
        tile_pin = "{}.{}".format(pb_name, tile_pin)

        if pin.direction == PinDirection.INPUT:
            ET.SubElement(
                xml_ic, "direct", {"name": "{}_to_{}".format(tile_pin, cell_pin), "input": tile_pin, "output": cell_pin}
            )

        elif pin.direction == PinDirection.OUTPUT:
            ET.SubElement(
                xml_ic, "direct", {"name": "{}_to_{}".format(cell_pin, tile_pin), "input": cell_pin, "output": tile_pin}
            )

        else:
            assert False, pin

    # If the tile has a fake const input then connect it to each cell wrapper
    if tile_type.fake_const_pin:
        tile_pin = "{}.FAKE_CONST".format(pb_name)

        for cell_type, cell_count in tile_type.cells.items():
            for i in range(cell_count):
                cell_pin = "{}[{}].{}".format(cell_type, i, "FAKE_CONST")

                ET.SubElement(
                    xml_ic,
                    "direct",
                    {"name": "{}_to_{}".format(tile_pin, cell_pin), "input": tile_pin, "output": cell_pin},
                )

    return xml_pb


def make_top_level_tile(tile_type, sub_tiles, tile_types, equivalent_tiles=None):
    """
    Makes a tile definition for the given tile
    """

    # The tile tag
    tl_name = "TL-{}".format(tile_type.upper())
    xml_tile = ET.Element(
        "tile",
        {
            "name": tl_name,
        },
    )

    # Make sub-tiles
    for sub_tile, capacity in sub_tiles.items():
        st_name = "ST-{}".format(sub_tile)

        # The sub-tile tag
        xml_sub_tile = ET.SubElement(xml_tile, "sub_tile", {"name": st_name, "capacity": str(capacity)})

        # Make the tile equivalent to itself
        if equivalent_tiles is None or sub_tile not in equivalent_tiles:
            equivalent_sub_tiles = {sub_tile: None}
        else:
            equivalent_sub_tiles = equivalent_tiles[sub_tile]

        # Top-level ports
        tile_pinlists = add_ports(xml_sub_tile, tile_types[sub_tile].pins, False)

        # Equivalent sites
        xml_equiv = ET.SubElement(xml_sub_tile, "equivalent_sites")
        for site_type, site_pinmap in equivalent_sub_tiles.items():
            # Site tag
            pb_name = "PB-{}".format(site_type.upper())
            xml_site = ET.SubElement(xml_equiv, "site", {"pb_type": pb_name, "pin_mapping": "custom"})

            # Same type, map one-to-one
            if tile_type.upper() == site_type.upper() or site_pinmap is None:
                all_pins = {**tile_pinlists["clock"], **tile_pinlists["input"], **tile_pinlists["output"]}

                for pin, count in all_pins.items():
                    assert count == 1, (pin, count)
                    ET.SubElement(
                        xml_site, "direct", {"from": "{}.{}".format(st_name, pin), "to": "{}.{}".format(pb_name, pin)}
                    )

            # Explicit pinmap as a list of tuples (from, to)
            elif isinstance(site_pinmap, list):
                for tl_pin, pb_pin in site_pinmap:
                    ET.SubElement(
                        xml_site,
                        "direct",
                        {"from": "{}.{}".format(st_name, tl_pin), "to": "{}.{}".format(pb_name, pb_pin)},
                    )

            # Should not happen
            else:
                assert False, (tl_name, st_name, pb_name)

        # TODO: Add "fc" override for direct tile-to-tile connections if any.

        # Pin locations
        pins_by_loc = {"left": [], "right": [], "bottom": [], "top": []}

        # Make input pins go towards top and output pins go towards right.
        for pin, count in itertools.chain(tile_pinlists["clock"].items(), tile_pinlists["input"].items()):
            assert count == 1, (pin, count)
            pins_by_loc["top"].append(pin)

        for pin, count in tile_pinlists["output"].items():
            assert count == 1, (pin, count)
            pins_by_loc["right"].append(pin)

        # Dump pin locations
        xml_pinloc = ET.SubElement(xml_sub_tile, "pinlocations", {"pattern": "custom"})
        for loc, pins in pins_by_loc.items():
            if len(pins):
                xml_loc = ET.SubElement(xml_pinloc, "loc", {"side": loc})
                xml_loc.text = " ".join(["{}.{}".format(st_name, pin) for pin in pins])

        # Switchblocks locations
        # This is actually not needed in the end but has to be present to make
        # VPR happy
        ET.SubElement(xml_sub_tile, "switchblock_locations", {"pattern": "all"})

    return xml_tile
