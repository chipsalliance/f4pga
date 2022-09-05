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
BLIF/EBLIF parsing, writing and manipulation utilities.

BLIF format specification:
    https://course.ece.cmu.edu/~ee760/760docs/blif.pdf

EBLIF format specification:
    https://docs.verilogtorouting.org/en/latest/vpr/file_formats/#extended-blif-eblif
"""

import re
from collections import OrderedDict

# =============================================================================


class Cell:
    """
    This class represents a single cell in a netlist
    """

    def __init__(self, type):

        # Cell name. This one is for reference only. It won't be writteb back
        # with the .cname attribute. Use the cname field for that.
        self.name = None

        # Cell type (model)
        self.type = type

        # Ports and connections. Indexed by port specificatons
        # (as <port>[<bit>]), contains net names.
        self.ports = OrderedDict()

        # For const sources ($const) this is the value of the constant
        # For luts ($lut) this is a list holding the truth table
        # For latches this is the initial value of the latch or None
        self.init = None

        # Extended EBLIF data
        self.cname = None
        self.attributes = OrderedDict()  # name: value, strings
        self.parameters = OrderedDict()  # name: value, strings

    def __str__(self):
        return "{} ({})".format(self.type, self.name)

    def __repr__(self):
        return str(self)


class Eblif:
    """
    This class represents a top-level module of a BLIF/EBLIF netlist

    The class contains BLIF/EBLIF parser and serialized. The parser support
    all EBLIF constructs except for .conn statements. It is possible to do a
    parser -> serializer round trip which should generate identical file as
    the one provided to the parser.

    Netlist cells are stored using the Cell class (see above).

    Cells defined as ".subckt <type>" are stored along with their type. Native
    BLIF cells (.names, .latch etc.) are represented via the following
    "built-in" cell models.

    * $const - A constant generator (0-LUT). The output port is named "out"
        and the init parameter is set to the constant value generated.

    * $lut - N-input LUT. The input port is named "lut_in" and the output one
        "lut_out". The init parameter contains the truth table. Log2 of size of
        the table defines the LUT width.

    * $latch - A generic ff/latch with unknown type. Common ports are named:
        "D", "Q", and "clock". The init value specifies initial ff/latch state
        a per BLIF specification.

    * $fe, $re, $ah, $al, $as - A ff/latch of type corresponding to BLIF
        definitions. Apart from different types these are identical to $latch

    * $input, $output - These are used to represent top-level IO ports. The
        cells have single port named "inpad" and "outpad" respectively. To
        create / remove such cells use convert_ports_to_cells() and
        convert_cells_to_ports() methods.
    """

    def __init__(self, model):

        # Top-level module name
        self.model = model

        # Top-level input and output nets
        self.inputs = []
        self.outputs = []

        # Cells (by names)
        self.cells = OrderedDict()

    def add_cell(self, cell):
        """
        Adds a cell. Generates its name if the cell doesn't have. Returns the
        name under which the cell is stored.
        """

        # No cell
        if cell is None:
            return None

        # Use the cell name
        if cell.name:
            name = cell.name

        # Generate a name
        else:
            index = 0
            while True:
                name = "{}{}".format(cell.type, index)
                if name not in self.cells:
                    cell.name = name
                    break

        # Add it
        assert cell.name not in self.cells, cell.name
        self.cells[cell.name] = cell

        return name

    def find_cell(self, name, use_cname=True):
        """
        Finds a cell in the netlist given its name, When use_cname is True
        then looks also by the cell's cname
        """

        # Try by name
        cell = self.cells.get(name, None)

        # Try by cname if allowed
        if cell is None and use_cname:
            for c in self.cells.values():
                if c.cname == name:
                    cell = c
                    break

        return cell

    def convert_ports_to_cells(self):
        """
        Converts top-level input and output ports to $input and $output cells
        """

        # Convert inputs
        for port in self.inputs:

            cell = Cell("$input")
            cell.name = port
            cell.ports["inpad"] = port

            self.add_cell(cell)

        # Convert outputs
        for port in self.outputs:

            cell = Cell("$output")
            cell.name = "out:" + port
            cell.cname = cell.name
            cell.ports["outpad"] = port

            self.add_cell(cell)

        # Clear top-level ports
        self.inputs = []
        self.outputs = []

    def convert_cells_to_ports(self):
        """
        Converts $input and $output cells into top-level ports
        """
        for key in list(self.cells.keys()):
            cell = self.cells[key]

            # Input
            if cell.type == "$input":
                assert "inpad" in cell.ports
                name = cell.ports["inpad"]

                self.inputs.append(name)
                del self.cells[key]

            # Output
            if cell.type == "$output":
                assert "outpad" in cell.ports
                name = cell.name.replace("out:", "")

                self.outputs.append(name)
                del self.cells[key]

                # Insert a buffer if the port name does not match the net name
                net = cell.ports["outpad"]
                if name != net:

                    cell = Cell("$lut")
                    cell.name = name
                    cell.ports["lut_in[0]"] = net
                    cell.ports["lut_out"] = name
                    cell.init = [0, 1]

                    self.add_cell(cell)

    @staticmethod
    def from_string(string):
        """
        Parses a BLIF/EBLIF netlist as a multi-line string. Returns an Eblif
        class instance.
        """

        def parse_single_output_cover(parts):
            """
            Parses a single output cover of a BLIF truth table.
            """

            # FIXME: Add support for don't cares
            if "-" in parts[0]:
                assert False, "Don't cares ('-') not supported yet!"

            # Assume only single address
            addr = int(parts[0][::-1], 2)
            data = int(parts[1])

            yield addr, data

        # Split lines, strip whitespace, remove blank ones
        lines = string.split("\n")
        lines = [line.strip() for line in lines]
        lines = [line for line in lines if line]

        eblif = None
        cell = None

        # Parse lines
        for line_no, line in enumerate(lines):
            fields = line.split()

            # Reject comments
            for i in range(len(fields)):
                if fields[i].startswith("#"):
                    fields = fields[:i]
                    break

            # Empty line
            if not fields:
                continue

            # Look for .model
            if fields[0] == ".model":
                eblif = Eblif(fields[1])
                continue

            # No EBLIF yet
            if not eblif:
                continue

            # Input list
            if fields[0] == ".inputs":
                eblif.inputs = fields[1:]

            # Output list
            elif fields[0] == ".outputs":
                eblif.outputs = fields[1:]

            # Got a generic cell
            elif fields[0] == ".subckt":
                assert len(fields) >= 2
                eblif.add_cell(cell)

                # Add the new cell
                cell = Cell(fields[1])

                # Add ports and net connections
                for conn in fields[2:]:
                    port, net = conn.split("=", maxsplit=1)
                    cell.ports[port] = net

            # Got a native flip-flop / latch
            elif fields[0] == ".latch":
                assert len(fields) >= 3
                eblif.add_cell(cell)

                # Add the new cell
                cell = Cell("$latch")

                # Input and output
                cell.ports["D"] = fields[1]
                cell.ports["Q"] = fields[2]

                # Got type and control
                if len(fields) >= 5:
                    cell.type = "$" + fields[3]
                    cell.ports["clock"] = fields[4]

                # Use the output net as cell name
                cell.name = cell.ports["Q"]

                # Got initial value
                if len(fields) >= 6:
                    cell.init = int(fields[5])
                else:
                    cell.init = 3  # Unknown

            # Got a native LUT
            elif fields[0] == ".names":
                assert len(fields) >= 2
                eblif.add_cell(cell)

                # Determine LUT width
                width = len(fields[1:-1])

                # Add the new cell
                type = "$lut" if width > 0 else "$const"
                cell = Cell(type)

                # Initialize the truth table
                if type == "$lut":
                    cell.init = [0 for i in range(2**width)]
                elif type == "$const":
                    cell.init = 0

                # Input connections
                for i, net in enumerate(fields[1:-1]):
                    port = "lut_in[{}]".format(i)
                    cell.ports[port] = net

                # Output connection
                cell.ports["lut_out"] = fields[-1]

                # Use the output net as cell name
                cell.name = cell.ports["lut_out"]

            # LUT truth table chunk
            elif all([c in ("0", "1", "-") for c in fields[0]]):
                assert cell is not None
                assert cell.type in ["$lut", "$const"]

                # The cell is a LUT
                if cell.type == "$lut":
                    assert len(fields) == 2
                    for addr, data in parse_single_output_cover(fields):
                        cell.init[addr] = data

                # The cell is a const source
                elif cell.type == "$const":
                    assert len(fields) == 1
                    cell.init = int(fields[0])

            # Cell name
            elif fields[0] == ".cname":
                cell.name = fields[1]
                cell.cname = cell.name

            # Cell attribute
            elif fields[0] == ".attr":
                cell.attributes[fields[1]] = fields[2]

            # Cell parameter
            elif fields[0] == ".param":
                cell.parameters[fields[1]] = fields[2]

            # End
            elif fields[0] == ".end":
                # FIXME: Mark that the end is reached and disregard following
                # keywords
                pass

            # Unknown directive
            else:
                assert False, line

        # Store the current cell
        eblif.add_cell(cell)

        return eblif

    @staticmethod
    def from_file(file_name):
        """
        Parses a BLIF/EBLIF file. Returns an Eblif class instance.
        """
        with open(file_name, "r") as fp:
            string = fp.read()
            return Eblif.from_string(string)

    def to_string(self, cname=True, attr=True, param=True, consts=True):
        """
        Formats EBLIF data as a multi-line EBLIF string. Additional parameters
        control what kind of extended (EBLIF) data will be written.
        """

        lines = []

        # Header
        lines.append(".model {}".format(self.model))
        lines.append(".inputs {}".format(" ".join(self.inputs)))
        lines.append(".outputs {}".format(" ".join(self.outputs)))

        # Cells
        for cell in self.cells.values():

            # A constant source
            if cell.type == "$const":

                # Skip consts
                if not consts:
                    continue

                lines.append(".names {}".format(str(cell.ports["lut_out"])))
                if cell.init != 0:
                    lines.append(str(cell.init))

            # A LUT
            elif cell.type == "$lut":

                # Identify LUT input pins and their bind indices
                nets = {}
                for port, net in cell.ports.items():
                    match = re.fullmatch(r"lut_in\[(?P<index>[0-9]+)\]", port)
                    if match is not None:
                        index = int(match.group("index"))
                        nets[index] = net

                # Write the cell header. Sort inputs by their indices
                keys = sorted(nets.keys())
                lines.append(".names {} {}".format(" ".join([nets[k] for k in keys]), str(cell.ports["lut_out"])))

                # Write the truth table
                fmt = "{:0" + str(len(nets)) + "b}"
                tab = []
                for addr, data in enumerate(cell.init):
                    if data != 0:
                        tab.append(fmt.format(addr)[::-1] + " 1")
                lines.extend(sorted(tab))

            # A latch
            elif cell.type in ["$fe", "$re", "$ah", "$al", "$as"]:

                line = ".latch {} {} {} {} {}".format(
                    str(cell.ports["D"]), str(cell.ports["Q"]), cell.type[1:], str(cell.ports["clock"]), str(cell.init)
                )
                lines.append(line)

            # A generic latch controlled by a single global clock
            elif cell.type == "$latch":

                line = ".latch {} {} {}".format(str(cell.ports["D"]), str(cell.ports["Q"]), str(cell.init))
                lines.append(line)

            # A generic subcircuit
            else:

                # The subcircuit along with its connections
                line = ".subckt {}".format(cell.type)
                for port, net in cell.ports.items():
                    line += " {}={}".format(port, net)
                lines.append(line)

                # Cell name
                if cname and cell.cname:
                    lines.append(".cname {}".format(cell.cname))

                # Cell attributes
                if attr:
                    for k, v in cell.attributes.items():
                        lines.append(".attr {} {}".format(k, v))

                # Cell parameters
                if param:
                    for k, v in cell.parameters.items():
                        lines.append(".param {} {}".format(k, v))

        # Footer
        lines.append(".end")

        # Join all lines
        return "\n".join(lines)

    def to_file(self, file_name, **kw):
        """
        Writes EBLIF data to a file
        """
        with open(file_name, "w") as fp:
            fp.write(self.to_string(**kw))
