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
import re

# =============================================================================

# A regex used for fixing pin names
RE_PIN_NAME = re.compile(r"^([A-Za-z0-9_]+)(?:\[([0-9]+)\])?$")

# =============================================================================


def get_pin_name(name):
    """
    Returns the pin name and its index in bus. If a pin is not a member of
    a bus then the index is None

    >>> get_pin_name("WIRE")
    ('WIRE', None)
    >>> get_pin_name("DATA[12]")
    ('DATA', 12)
    """

    match = re.match(r"(?P<name>.*)\[(?P<idx>[0-9]+)\]$", name)
    if match:
        return match.group("name"), int(match.group("idx"))
    else:
        return name, None


def fixup_pin_name(name):
    """
    Renames a pin to make its name suitable for VPR.

    >>> fixup_pin_name("A_WIRE")
    'A_WIRE'
    >>> fixup_pin_name("ADDRESS[17]")
    'ADDRESS_17'
    >>> fixup_pin_name("DATA[11]_X")
    Traceback (most recent call last):
        ...
    AssertionError: DATA[11]_X
    """

    match = RE_PIN_NAME.match(name)
    assert match is not None, name

    groups = match.groups()
    if groups[1] is None:
        return groups[0]
    else:
        return "{}_{}".format(*groups)


# =============================================================================


def yield_muxes(switchbox):
    """
    Yields all muxes of a switchbox. Returns tuples with:
    (stage, switch, mux)
    """

    for stage in switchbox.stages.values():
        for switch in stage.switches.values():
            for mux in switch.muxes.values():
                yield stage, switch, mux


# =============================================================================


def get_quadrant_for_loc(loc, quadrants):
    """
    Assigns a quadrant to the given location. Returns None if no one matches.
    """

    for quadrant in quadrants.values():
        if loc.x >= quadrant.x0 and loc.x <= quadrant.x1:
            if loc.y >= quadrant.y0 and loc.y <= quadrant.y1:
                return quadrant

    return None


def get_loc_of_cell(cell_name, tile_grid):
    """
    Returns loc of a cell with the given name in the tilegrid.
    """

    # Look for a tile that has the cell
    for loc, tile in tile_grid.items():
        if tile is None:
            continue

        cell_names = [c.name for c in tile.cells]
        if cell_name in cell_names:
            return loc

    # Not found
    return None


def find_cell_in_tile(cell_name, tile):
    """
    Finds a cell instance with the given name inside the given tile.
    Returns the Cell object if found and None otherwise.
    """
    for cell in tile.cells:
        if cell.name == cell_name:
            return cell

    return None


# =============================================================================


def add_named_item(item_dict, item, item_name):
    """
    Adds a named item to the given dict if not already there. If it is there
    then returns the one from the dict.
    """

    if item_name not in item_dict:
        item_dict[item_name] = item

    return item_dict[item_name]


# =============================================================================


def natural_keys(text):
    """
    alist.sort(key=natural_keys) sorts in human order
    http://nedbatchelder.com/blog/200712/human_sorting.html
    (See Toothy's implementation in the comments)

    https://stackoverflow.com/questions/5967500/how-to-correctly-sort-a-string-with-a-number-inside
    """

    def atoi(text):
        return int(text) if text.isdigit() else text

    return [atoi(c) for c in re.split(r"(\d+)", text)]
