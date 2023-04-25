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
from collections import namedtuple, defaultdict

from f4pga.utils.quicklogic.pp3.data_structs import PinDirection

Element = namedtuple("Element", "loc type name ios")
Wire = namedtuple("Wire", "srcloc name inverted")
VerilogIO = namedtuple("VerilogIO", "name direction ioloc")


def loc2str(loc):
    return "X" + str(loc.x) + "Y" + str(loc.y)


class VModule(object):
    """Represents a Verilog module for QLAL4S3B FASM"""

    def __init__(
        self,
        vpr_tile_grid,
        vpr_tile_types,
        cells_library,
        pcf_data,
        belinversions,
        interfaces,
        designconnections,
        org_loc_map,
        cand_map,
        inversionpins,
        io_to_fbio,
        useinversionpins=True,
    ):
        """Prepares initial structures.

        Refer to fasm2bels.py for input description.
        """

        self.vpr_tile_grid = vpr_tile_grid
        self.vpr_tile_types = vpr_tile_types
        self.cells_library = cells_library
        self.pcf_data = pcf_data
        self.belinversions = belinversions
        self.interfaces = interfaces
        self.designconnections = designconnections
        self.org_loc_map = org_loc_map
        self.cand_map = cand_map
        self.inversionpins = inversionpins
        self.useinversionpins = useinversionpins
        self.io_to_fbio = io_to_fbio

        # dictionary holding inputs, outputs
        self.ios = {}
        # dictionary holding declared wires (wire value;)
        self.wires = {}
        # dictionary holding Verilog elements
        self.elements = defaultdict(dict)
        # dictionary holding assigns (assign key = value;)
        self.assigns = {}

        # helper representing last input id
        self.last_input_id = 0
        # helper representing last output id
        self.last_output_id = 0

        self.qlal4s3bmapping = {
            "LOGIC": "logic_cell_macro",
            "ASSP": "qlal4s3b_cell_macro",
            "BIDIR": "gpio_cell_macro",
            "RAM": "ram8k_2x1_cell_macro",
            "MULT": "qlal4s3_mult_cell_macro",
            "GMUX": "gclkbuff",
            "QMUX": "qhsckbuff",
            "CLOCK": "ckpad",
            "inv": "inv",
        }

        self.qlal4s3_pinmap = {
            "ckpad": {
                "IP": "P",
                "IC": "Q",
            },
            "gclkbuff": {
                "IC": "A",
                "IZ": "Z",
            },
            "qhsckbuff": {"HSCKIN": "A", "IZ": "Z"},
        }

    def group_vector_signals(self, signals, io=False):
        # IOs beside name, have also direction, convert them to format
        # we can process
        if io:
            orig_ios = signals
            ios = dict()
            for s in signals:
                id = Wire(s.name, "io", False)
                ios[id] = s.name
            signals = ios

        vectors = dict()
        new_signals = dict()

        array = re.compile(r"(?P<varname>[a-zA-Z_][a-zA-Z_0-9$]+)\[(?P<arrindex>[0-9]+)\]")

        # first find the vectors
        for signalid in signals:
            match = array.match(signals[signalid])
            if match:
                varname = match.group("varname")
                arrayindex = int(match.group("arrindex"))

                if varname not in vectors:
                    vectors[varname] = dict()
                    vectors[varname]["max"] = 0
                    vectors[varname]["min"] = 0

                if arrayindex > vectors[varname]["max"]:
                    vectors[varname]["max"] = arrayindex

                if arrayindex < vectors[varname]["min"]:
                    vectors[varname]["min"] = arrayindex

            # if signal is not a part of a vector leave it
            else:
                new_signals[signalid] = signals[signalid]

        # add vectors to signals dict
        for vec in vectors:
            name = "[{max}:{min}] {name}".format(max=vectors[vec]["max"], min=vectors[vec]["min"], name=vec)
            id = Wire(name, "vector", False)
            new_signals[id] = name

        if io:
            # we need to restore the direction info
            new_ios = list()
            for s in new_signals:
                signalname = new_signals[s].split()
                signalname = signalname[-1]
                io = [x.direction for x in orig_ios if x.name.startswith(signalname)]
                direction = io[0]
                new_ios.append((direction, new_signals[s]))
            return new_ios
        else:
            return new_signals

    def group_array_values(self, parameters: dict):
        """Groups pin names that represent array indices.

        Parameters
        ----------
        parameters: dict
            A dictionary holding original parameters

        Returns
        -------
        dict: parameters with grouped array indices
        """
        newparameters = dict()
        arraydst = re.compile(r"(?P<varname>[a-zA-Z_][a-zA-Z_0-9$]+)\[(?P<arrindex>[0-9]+)\]")
        for dst, src in parameters.items():
            match = arraydst.match(dst)
            if match:
                varname = match.group("varname")
                arrindex = int(match.group("arrindex"))
                if varname not in newparameters:
                    newparameters[varname] = {arrindex: src}
                else:
                    newparameters[varname][arrindex] = src
            else:
                newparameters[dst] = src
        return newparameters

    def form_simple_assign(self, loc, parameters):
        ioname = self.get_io_name(loc)

        assign = ""
        direction = self.get_io_config(parameters)

        if direction == "input":
            assign = "    assign {} = {};".format(parameters["IZ"], ioname)
        elif direction == "output":
            assign = "    assign {} = {};".format(ioname, parameters["OQI"])
        elif direction is None:
            pass
        else:
            assert False, "Unknown IO configuration"

        return assign

    def form_verilog_element(self, loc, typ: str, name: str, parameters: dict):
        """Creates an entry representing single Verilog submodule.

        Parameters
        ----------
        loc: Loc
            Cell coordinates
        typ: str
            Cell type
        name: str
            Name of the submodule
        parameters: dict
            Map from input pin to source wire

        Returns
        -------
        str: Verilog entry
        """
        if typ == "BIDIR":
            # We do not emit the BIDIR cell for non inout IOs
            direction = self.get_io_config(parameters)
            if direction is None:
                return ""
            elif direction != "inout":
                return self.form_simple_assign(loc, parameters)

        params = []
        moduletype = self.qlal4s3bmapping[typ]
        pin_map = self.qlal4s3_pinmap.get(moduletype, dict())
        result = f"    {moduletype} {name} ("
        fixedparameters = self.group_array_values(parameters)
        # get inputs, strip vector's pin indexes
        input_pins = [
            pin.name.split("[")[0] for pin in self.cells_library[typ].pins if pin.direction == PinDirection.INPUT
        ]
        dummy_wires = []

        for inpname, inp in fixedparameters.items():
            mapped_inpname = pin_map.get(inpname, inpname)
            if isinstance(inp, dict):
                arr = []
                dummy_wire = f"{moduletype}_{name}_{inpname}"
                max_dummy_index = 0
                need_dummy = False
                maxindex = max([val for val in inp.keys()])
                for i in reversed(range(maxindex + 1)):
                    if i not in inp:
                        # do not assign constants to outputs
                        if inpname in input_pins:
                            arr.append("1'b0")
                        else:
                            if i > max_dummy_index:
                                max_dummy_index = i
                            arr.append("{}[{}]".format(dummy_wire, i))
                            need_dummy = True
                    else:
                        arr.append(inp[i])
                arrlist = ", ".join(arr)
                params.append(f".{mapped_inpname}({{{arrlist}}})")
                if need_dummy:
                    dummy_wires.append(f"    wire [{max_dummy_index}:0] {dummy_wire};")
            else:
                params.append(f".{mapped_inpname}({inp})")
        if self.useinversionpins:
            if typ in self.inversionpins:
                for toinvert, inversionpin in self.inversionpins[typ].items():
                    if toinvert in self.belinversions[loc][typ]:
                        params.append(f".{inversionpin}(1'b1)")
                    else:
                        params.append(f".{inversionpin}(1'b0)")

        # handle BIDIRs and CLOCKs
        if typ in ["CLOCK", "BIDIR"]:
            ioname = self.get_io_name(loc)

            moduletype = self.qlal4s3bmapping[typ]
            pin_map = self.qlal4s3_pinmap.get(moduletype, dict())

            params.append(".{}({})".format(pin_map.get("IP", "IP"), ioname))

        result += f',\n{" " * len(result)}'.join(sorted(params)) + ");\n"
        wires = ""
        for wire in dummy_wires:
            wires += f"\n{wire}"
        result = wires + "\n\n" + result
        return result

    @staticmethod
    def get_element_name(type, loc):
        """Forms element name from its type and FASM feature name."""
        return f"{type}_X{loc.x}_Y{loc.y}"

    @staticmethod
    def get_element_type(type):
        match = re.match(r"(?P<type>[A-Za-z]+)(?P<index>[0-9]+)?", type)
        assert match is not None, type
        return match.group("type")

    def get_bel_type_and_connections(self, loc, connections, direction):
        """For a given connection list returns a dictionary
        with bel types and connections to them
        """

        cells = self.vpr_tile_grid[loc].cells

        if type(connections) == str:
            inputnames = [connections]
            # convert connections to dict
            connections = dict()
            connections[inputnames[0]] = inputnames[0]
        else:
            inputnames = [name for name in connections.keys()]

        # Some switchbox inputs are named like "<cell><cell_index>_<pin>"
        # Make a list of them for compatison in the following step.
        cell_input_names = defaultdict(lambda: [])
        for name in inputnames:
            fields = name.split("_", maxsplit=1)
            if len(fields) == 2:
                cell, pin = fields
                cell_input_names[cell].append(pin)

        used_cells = []
        for cell in cells:
            cell_name = "{}{}".format(cell.type, cell.index)

            cellpins = [pin.name for pin in self.cells_library[cell.type].pins if pin.direction == direction]

            # check every connection pin if it has
            for pin in cellpins:
                # Cell name and pin name match
                if cell_name in cell_input_names:
                    if pin in cell_input_names[cell_name]:
                        used_cells.append(cell)
                        break

                # The pin name matches exactly the specified input name
                if pin in inputnames:
                    used_cells.append(cell)
                    break

        # assing connection to a cell
        cell_connections = {}
        for cell in used_cells:
            cell_name = "{}{}".format(cell.type, cell.index)

            cell_connections[cell_name] = dict()
            cellpins = [pin.name for pin in self.cells_library[cell.type].pins if pin.direction == direction]

            for key in connections.keys():
                if key in cellpins:
                    cell_connections[cell_name][key] = connections[key]

                # Some switchbox inputs are named like
                # "<cell><cell_index>_<pin>". Break down the name and check.
                fields = key.split("_", maxsplit=1)
                if len(fields) == 2:
                    key_cell, key_pin = fields
                    if key_cell == cell_name and key_pin in cellpins:
                        cell_connections[cell_name][key_pin] = connections[key]

        return cell_connections

    def new_io_name(self, direction):
        """Creates a new IO name for a given direction.

        Parameters
        ----------
        direction: str
            Direction of the IO, can be 'input' or 'output'
        """
        # TODO add support for inout
        assert direction in ["input", "output", "inout"]
        if direction == "output":
            name = f"out_{self.last_output_id}"
            self.last_output_id += 1
        elif direction == "input":
            name = f"in_{self.last_input_id}"
            self.last_input_id += 1
        else:
            pass
        return name

    def get_wire(self, loc, wire, inputname):
        """Creates or gets an existing wire for a given source.

        Parameters
        ----------
        loc: Loc
            Location of the destination cell
        wire: tuple
            A tuple of location of the source cell and source pin name
        inputname: str
            A name of the destination pin

        Returns
        -------
        str: wire name
        """
        isoutput = self.vpr_tile_grid[loc].type == "SYN_IO"
        if isoutput:
            # outputs are never inverted
            inverted = False
        else:
            # determine if inverted
            inverted = inputname in self.belinversions[loc][self.vpr_tile_grid[loc].type]
        wireid = Wire(wire[0], wire[1], inverted)
        if wireid in self.wires:
            # if wire already exists, use it
            return self.wires[wireid]

        # first create uninverted wire
        uninvertedwireid = Wire(wire[0], wire[1], False)
        if uninvertedwireid in self.wires:
            # if wire already exists, use it
            wirename = self.wires[uninvertedwireid]
        else:
            srcname = self.vpr_tile_grid[wire[0]].name
            type_connections = self.get_bel_type_and_connections(wire[0], wire[1], PinDirection.OUTPUT)
            # there should be only one type here
            srctype = [type for type in type_connections.keys()][0]
            srconame = wire[1]
            if srctype == "SYN_IO":
                # if source is input, use its name
                if wire[0] not in self.ios:
                    self.ios[wire[0]] = VerilogIO(name=self.new_io_name("input"), direction="input", ioloc=wire[0])
                assert self.ios[wire[0]].direction == "input"
                wirename = self.ios[wire[0]].name
            else:
                # form a new wire name
                wirename = f"{srcname}_{srconame}"
            if srctype not in self.elements[wire[0]]:
                # if the source element does not exist, create it
                self.elements[wire[0]][srctype] = Element(
                    wire[0],
                    self.get_element_type(srctype),
                    self.get_element_name(srctype, wire[0]),
                    {srconame: wirename},
                )
            else:
                # add wirename to the existing element
                self.elements[wire[0]][srctype].ios[srconame] = wirename
            if not isoutput and srctype != "SYN_IO":
                # add wire
                self.wires[uninvertedwireid] = wirename
            elif isoutput:
                # add assign to output
                self.assigns[self.ios[loc].name] = wirename

        if not inverted or (self.useinversionpins and inputname in self.inversionpins[self.vpr_tile_grid[loc].type]):
            # if not inverted or we're not inverting, just finish
            return wirename

        # else create an inverted and wire for it
        invertername = f"{wirename}_inverter"

        invwirename = f"{wirename}_inv"

        inverterios = {"Q": invwirename, "A": wirename}

        inverterelement = Element(wire[0], "inv", invertername, inverterios)
        self.elements[wire[0]]["inv"] = inverterelement
        invertedwireid = Wire(wire[0], wire[1], True)
        self.wires[invertedwireid] = invwirename
        return invwirename

    def parse_bels(self):
        """Converts BELs to Verilog-like structures."""
        # TODO add support for direct input-to-output
        # first parse outputs to create wires for them

        # parse outputs first to properly handle namings
        for currloc, connections in self.designconnections.items():
            type_connections = self.get_bel_type_and_connections(currloc, connections, PinDirection.OUTPUT)

            for currtype, connections in type_connections.items():
                currname = self.get_element_name(currtype, currloc)
                outputs = {}

                # Check each output
                for output_name, (
                    loc,
                    wire,
                ) in connections.items():
                    # That wire is connected to something. Skip processing
                    # of the cell here
                    if loc is not None:
                        continue

                    # Connect the global wire
                    outputs[output_name] = wire

                # No outputs connected, don't add.
                if not len(outputs):
                    continue

                # If Element does not exist, create it
                if currtype not in self.elements[currloc]:
                    self.elements[currloc][currtype] = Element(
                        currloc, self.get_element_type(currtype), currname, outputs
                    )
                # Else update IOs
                else:
                    self.elements[currloc][currtype].ios.update(outputs)

        # process of BELs
        for currloc, connections in self.designconnections.items():
            # Extract type and form name for the BEL
            # Current location may be a multi cell location.
            # Split the connection list into a to a set of connections
            # for each used cell type
            type_connections = self.get_bel_type_and_connections(currloc, connections, PinDirection.INPUT)

            for currtype in type_connections:
                currname = self.get_element_name(currtype, currloc)
                connections = type_connections[currtype]
                inputs = {}
                # form all inputs for the BEL
                for inputname, wire in connections.items():
                    if wire[1] == "VCC":
                        inputs[inputname] = "1'b1"
                        continue
                    elif wire[1] == "GND":
                        inputs[inputname] = "1'b0"
                        continue
                    elif wire[1].startswith("CAND"):
                        dst = (currloc, inputname)
                        dst = self.org_loc_map.get(dst, dst)
                        if dst[0] in self.cand_map:
                            inputs[inputname] = self.cand_map[dst[0]][wire[1]]
                        continue
                    srctype = self.vpr_tile_grid[wire[0]].type
                    srctype_cells = self.vpr_tile_types[srctype].cells
                    if len(set(srctype_cells).intersection(set(["BIDIR", "LOGIC", "ASSP", "RAM", "MULT"]))) > 0:
                        # FIXME handle already inverted pins
                        # TODO handle inouts
                        wirename = self.get_wire(currloc, wire, inputname)
                        inputs[inputname] = wirename
                    else:
                        raise Exception("Not supported cell type {}".format(srctype))
                if currtype not in self.elements[currloc]:
                    # If Element does not exist, create it
                    self.elements[currloc][currtype] = Element(
                        currloc, self.get_element_type(currtype), currname, inputs
                    )
                else:
                    # else update IOs
                    self.elements[currloc][currtype].ios.update(inputs)

        # Prune BELs that do not drive anythin (have all outputs disconnected)
        for loc, elements in list(self.elements.items()):
            for type, element in list(elements.items()):
                # Handle IO cells
                if element.type in ["CLOCK", "BIDIR", "SDIOMUX"]:
                    if element.type == "CLOCK":
                        direction = "input"
                    else:
                        direction = self.get_io_config(element.ios)

                    # Remove the cell if none is connected
                    if direction is None:
                        del elements[type]

                # Handle non-io cells
                else:
                    # Get connected pin names and output pin names
                    connected_pins = set(element.ios.keys())
                    output_pins = set(
                        [
                            pin.name.split("[")[0]
                            for pin in self.cells_library[element.type].pins
                            if pin.direction == PinDirection.OUTPUT
                        ]
                    )

                    # Remove the cell if none is connected
                    if not len(connected_pins & output_pins):
                        del elements[type]

            # Prune the whole location
            if not len(elements):
                del self.elements[loc]

    def get_io_name(self, loc):
        # default pin name
        name = loc2str(loc) + "_inout"
        # check if we have the original name for this io
        if self.pcf_data is not None:
            pin = self.io_to_fbio.get(loc, None)
            if pin is not None and pin in self.pcf_data:
                name = self.pcf_data[pin]
                name = name.replace("(", "[")
                name = name.replace(")", "]")

        return name

    def get_io_config(self, ios):
        # decode direction
        # direction is configured by routing 1 or 0 to certain inputs

        if "IE" in ios:
            output_en = ios["IE"] != "1'b0"
        else:
            # outputs is enabled by default
            output_en = True
        if "INEN" in ios:
            input_en = ios["INEN"] != "1'b0"
        else:
            # inputs are disabled by default
            input_en = False

        if input_en and output_en:
            direction = "inout"
        elif input_en:
            direction = "input"
        elif output_en:
            direction = "output"
        else:
            direction = None

        # Output unrouted. Discard
        if direction == "input":
            if "IZ" not in ios:
                return None

        return direction

    def generate_ios(self):
        """Generates IOs and their wires

        Returns
        -------
        None
        """
        for eloc, locelements in self.elements.items():
            for element in locelements.values():
                if element.type in ["CLOCK", "BIDIR", "SDIOMUX"]:
                    if element.type == "CLOCK":
                        direction = "input"
                    else:
                        direction = self.get_io_config(element.ios)

                    # Add the input if used
                    if direction is not None:
                        name = self.get_io_name(eloc)
                        self.ios[eloc] = VerilogIO(name=name, direction=direction, ioloc=eloc)

    def generate_verilog(self):
        """Creates Verilog module

        Returns
        -------
        str: A Verilog module for given BELs
        """
        ios = ""
        wires = ""
        assigns = ""
        elements = ""

        self.generate_ios()

        if len(self.ios) > 0:
            sortedios = sorted(self.ios.values(), key=lambda x: (x.direction, x.name))
            grouped_ios = self.group_vector_signals(sortedios, True)
            ios = "\n    "
            ios += ",\n    ".join([f"{x[0]} {x[1]}" for x in grouped_ios])

        grouped_wires = self.group_vector_signals(self.wires)
        if len(grouped_wires) > 0:
            wires += "\n"
            for wire in grouped_wires.values():
                wires += f"    wire {wire};\n"

        if len(self.assigns) > 0:
            assigns += "\n"
            for dst, src in self.assigns.items():
                assigns += f"    assign {dst} = {src};\n"

        if len(self.elements) > 0:
            for eloc, locelements in self.elements.items():
                for element in locelements.values():
                    if element.type != "SYN_IO":
                        elements += "\n"
                        elements += self.form_verilog_element(eloc, element.type, element.name, element.ios)

        verilog = f"module top ({ios});\n" f"{wires}" f"{assigns}" f"{elements}" f"\n" f"endmodule"
        return verilog

    def generate_pcf(self):
        pcf = ""
        for io in self.ios.values():
            if io.ioloc in self.io_to_fbio:
                pcf += f"set_io {io.name} {self.io_to_fbio[io.ioloc]}\n"
        return pcf

    def generate_qcf(self):
        qcf = "#[Fixed Pin Placement]\n"
        for io in self.ios.values():
            if io.ioloc in self.io_to_fbio:
                qcf += f"place {io.name} {self.io_to_fbio[io.ioloc]}\n"
        return qcf
