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
This file contains definitions of various data structutes used to hold tilegrid
and routing information of a Quicklogic FPGA.
"""
from collections import namedtuple
from enum import Enum

# =============================================================================
"""
Pin direction in terms of its function.
"""


class PinDirection(Enum):
    UNSPEC = 0
    INPUT = 1
    OUTPUT = 2


"""
An opposite direction map
"""
OPPOSITE_DIRECTION = {
    PinDirection.UNSPEC: PinDirection.UNSPEC,
    PinDirection.INPUT: PinDirection.OUTPUT,
    PinDirection.OUTPUT: PinDirection.INPUT,
}
"""
A generic pin
"""
Pin = namedtuple("Pin", "name direction attrib")
"""
Pin direction in therms where is it "standing out" of a tile.
"""


class PinSide(Enum):
    UNSPEC = 0
    NORTH = 1
    SOUTH = 2
    EAST = 3
    WEST = 4


"""
This is a generic location in the tilegrid. Note that it also encounters for
the sub-tile index z.
"""
Loc = namedtuple("Loc", "x y z")
"""
FPGA grid quadrant.
"""
Quadrant = namedtuple("Quadrant", "name x0 y0 x1 y1")
"""
Forwads and backward location mapping
"""
LocMap = namedtuple("LocMap", "fwd bwd")

# =============================================================================
"""
A cell type within a tile type representation (should be named "site" ?).
Holds the cell type name and the list of its pins.
"""
CellType = namedtuple("CellType", "type pins")
"""
A cell instance within a tile. Binds a cell name with its type.

type    - Cell type
index   - Index within the tile
name    - Cell name (not necessarly unique)
alias   - Cell alias (if present)
"""
Cell = namedtuple("Cell", "type index name alias")

# =============================================================================


class TileType(object):
    """
    A tile type representation. The Quicklogic FPGA fabric does not define tiles.
    It has rather a group of cells bound to a common geographical location.
    """

    def __init__(self, type, cells, fake_const_pin=False):
        self.type = type
        self.cells = cells
        self.pins = []
        self.fake_const_pin = fake_const_pin

    def make_pins(self, cells_library):
        """
        Basing on the cell list and their pins generates the tile pins.
        """
        self.pins = []

        # Copy pins from all cells. Prefix their names with a cell name.
        for cell_type, cell_count in self.cells.items():
            for i in range(cell_count):
                for pin in cells_library[cell_type].pins:
                    name = "{}{}_{}".format(cell_type, i, pin.name)

                    self.pins.append(Pin(name=name, direction=pin.direction, attrib=pin.attrib))

        # Add the fake constant connection pin if marked
        if self.fake_const_pin:
            self.pins.append(Pin(name="FAKE_CONST", direction=PinDirection.INPUT, attrib={}))


"""
A tile instance within a tilegrid

type    - Tile type
name    - Tile instance name
cells   - A list of Cell objects
"""
Tile = namedtuple("Tile", "type name cells")

# =============================================================================


class SwitchboxPinType(Enum):
    """
    Switchbox pin types.
    """

    UNSPEC = 0  # Unknown.
    LOCAL = 1  # Connects to the tile at the same location as the switchbox.
    HOP = 2  # Generic hop, connects to another switchbox.
    GCLK = 3  # Connects to the global clock network.
    CONST = 4  # Connects to the global const network.
    FOREIGN = 5  # Connects to a tile at a different location.


"""
A location that identifies a pin inside a switchbox.

stage_id      - Stage id
switch_id     - Switch id within the stage
mux_id        - Mux id within the switch
pin_id        - Pin id of the mux
pin_direction - Logical direction of the pin
"""
SwitchboxPinLoc = namedtuple("SwitchboxPinLoc", "stage_id switch_id mux_id pin_id pin_direction")
"""
A top-level switchbox pin.

in          - Pin id.
name        - Pin name
direction   - Pin direction.
locs        - A list of SwitchboxPinLoc objects representing connections to
              switches within the switchbox.
type        - The pin type as according to SwitchboxPinType
"""
SwitchboxPin = namedtuple("SwitchboxPin", "id name direction locs type")
"""
A switch pin within a switchbox

id          - Pin id.
name        - Pin name. Only for top-level pins. For others is None.
direction   - Pin direction.
"""
SwitchPin = namedtuple("SwitchPin", "id name direction")
"""
A connection within a switchbox

src         - Source location (always an output pin)
dst         - Destination location (always an input pin)
"""
SwitchConnection = namedtuple("SwitchConnection", "src dst")
"""
Sink timing

tdel        - Constant propagation delay.
c           - Load capacitance.
vpr_switch  - VPR switch name
"""
SinkTiming = namedtuple("SinkTiming", "tdel c vpr_switch")
"""
Driver timing

tdel        - Constant propagation delay.
r           - Driver resitance.
vpr_switch  - VPR switch name
"""
DriverTiming = namedtuple("DriverTiming", "tdel r vpr_switch")
"""
Mux edge timing data

driver      - Driver parameters
sink        - Sink parameters
"""
MuxEdgeTiming = namedtuple("MuxEdgeTiming", "driver sink")

# =============================================================================


class Switchbox(object):
    """
    This class holds information about a routing switchbox of a particular type.

    A switchbox is implemented in CLOS architecture. It contains of multiple
    "stages". Outputs of previous stage go to the next one. A stage contains
    multiple switches. Each switch is a small M-to-N routing box.
    """

    class Mux(object):
        """
        An individual multiplexer inside a switchbox
        """

        def __init__(self, id, switch):
            self.id = id  # The mux ID
            self.switch = switch  # Parent switch od
            self.inputs = {}  # Input pins by their IDs
            self.output = None  # The output pin
            self.timing = {}  # Input timing (per input)

        @property
        def pins(self):
            """
            Yields all pins of the mux
            """
            for pin in self.inputs.values():
                yield pin

            yield self.output

    class Switch(object):
        """
        This is a sub-switchbox of a switchbox stage.
        """

        def __init__(self, id, stage):
            self.id = id  # The switch ID
            self.stage = stage  # Parent stage id
            self.muxes = {}  # Muxes by their IDs

        @property
        def pins(self):
            """
            Yields all pins of the switch
            """
            for mux in self.muxes.values():
                yield from mux.pins

    class Stage(object):
        """
        Represents a routing stage which has some attributes and consists of
        a column of Switch objects
        """

        def __init__(self, id, type=None):
            self.id = id  # The stage ID
            self.type = type  # The stage type ("HIGHWAY" or "STREET")
            self.switches = {}  # Switches indexed by their IDs

        @property
        def pins(self):
            """
            Yields all pins of the stage
            """
            for switch in self.switches.values():
                yield from switch.pins

    # ...............................................................

    def __init__(self, type):
        self.type = type  # Switchbox type
        self.inputs = {}  # Top-level inputs by their names
        self.outputs = {}  # Top-level outputs by their names
        self.stages = {}  # Stages by their IDs

        self.connections = set()  # Connections between stages

    @property
    def pins(self):
        """
        Yields all pins of the switchbox
        """
        for pin in self.inputs.values():
            yield pin
        for pin in self.outputs.values():
            yield pin


# =============================================================================
"""
A global clock network cell

type        - Cell type.
name        - Cell name.
loc         - Location in the grid.
quadrant    - Clock quadrant
pin_map     - A dict with mapping of cell pins to switchbox pins.
"""
ClockCell = namedtuple("ClockCell", "type name loc quadrant pin_map")

# =============================================================================


class ConnectionType(Enum):
    """
    Connection endpoint type
    """

    UNSPEC = 0  # Unspecified
    SWITCHBOX = 1  # Connection to a pin of a switchbox
    TILE = 2  # Connection to a pin of a tile
    CLOCK = 3  # Connection to a global clock network cell modelled using
    # routing resources only.


# A connection endpoint location. Specifies location, pin name and connection
# type.
ConnectionLoc = namedtuple("ConnectionLoc", "loc pin type")

# A connection within the tilegrid
Connection = namedtuple("Connection", "src dst is_direct")

# =============================================================================
"""
A package pin. Holds information about what cells the pin cooresponds to and
where it is in the tilegrid.

name    - The pin name
alias   - Alias
loc     - Location in the physical FPGA gric
cell    - Cell object that the package pin correspond to
"""
PackagePin = namedtuple("PackagePin", "name alias loc cell")

# =============================================================================

# VPR segment
VprSegment = namedtuple("VprSegment", "name length r_metal c_metal")

# VPR switch
VprSwitch = namedtuple("VprSwitch", "name type t_del r c_in c_out c_int")
