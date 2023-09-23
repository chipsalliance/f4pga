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
import argparse
import pickle
import re
from collections import defaultdict, namedtuple
import fasm

from f4pga.aux.utils.quicklogic.pp3.connections import get_name_and_hop

from pathlib import Path
from f4pga.aux.utils.quicklogic.pp3.data_structs import Loc, SwitchboxPinLoc, PinDirection, ConnectionType
from f4pga.aux.utils.quicklogic.pp3.utils import get_quadrant_for_loc
from f4pga.aux.utils.quicklogic.pp3.verilogmodule import VModule

from quicklogic_fasm.qlfasm import load_quicklogic_database, get_db_dir
from quicklogic_fasm.qlfasm import QL732BAssembler

Feature = namedtuple("Feature", "loc typ signature value")
RouteEntry = namedtuple("RouteEntry", "typ stage_id switch_id mux_id sel_id")
MultiLocCellMapping = namedtuple("MultiLocCellMapping", "typ fromlocset toloc pinnames")


class Fasm2Bels(object):
    """Class for parsing FASM file and producing BEL representation.

    It takes FASM lines and VPR database and converts the data to Basic
    Elements and connections between them. It allows converting this data to
    Verilog.
    """

    class Fasm2BelsException(Exception):
        """Exception for Fasm2Bels errors and unsupported features."""

        def __init__(self, message):
            self.message = message

        def __str__(self):
            return self.message

    def __init__(self, phy_db, device_name, package_name):
        """Prepares required structures for converting FASM to BELs.

        Parameters
        ----------
        phy_db: dict
            A dictionary containing cell_library, loc_map, vpr_tile_types,
            vpr_tile_grid, vpr_switchbox_types, vpr_switchbox_grid,
            connections, vpr_package_pinmaps
        """

        # load phy_db data
        self.quadrants = phy_db["phy_quadrants"]
        self.cells_library = phy_db["cells_library"]
        self.vpr_tile_types = phy_db["tile_types"]
        self.vpr_tile_grid = phy_db["phy_tile_grid"]
        self.vpr_switchbox_types = phy_db["switchbox_types"]
        self.vpr_switchbox_grid = phy_db["switchbox_grid"]
        self.connections = phy_db["connections"]

        self.device_name = device_name
        self.package_name = package_name

        self.io_to_fbio = dict()

        if self.package_name not in db["package_pinmaps"]:
            raise self.Fasm2BelsException(
                "ERROR: '{}' is not a vaild package for device '{}'. Valid ones are: {}".format(
                    self.package_name, self.device_name, ", ".join(db["package_pinmaps"].keys())
                )
            )

        for name, package in db["package_pinmaps"][self.package_name].items():
            self.io_to_fbio[package[0].loc] = name

        # Add ASSP to all locations it covers
        # TODO maybe this should be added in original vpr_tile_grid
        # set all cels in row 1 and column 2 to ASSP
        # In VPR grid, the ASSP tile is located in (1, 1)
        assplocs = set()
        ramlocs = dict()
        multlocs = dict()

        for phy_loc, tile in self.vpr_tile_grid.items():
            tile_type = self.vpr_tile_types[tile.type]
            if "ASSP" in tile_type.cells:
                assplocs.add(phy_loc)

            if "RAM" in tile_type.cells:
                ramcell = [cell for cell in tile.cells if cell.type == "RAM"]
                cellname = ramcell[0].name
                if cellname not in ramlocs:
                    ramlocs[cellname] = set()

                ramlocs[cellname].add(phy_loc)

            if "MULT" in tile_type.cells:
                multcell = [cell for cell in tile.cells if cell.type == "MULT"]
                cellname = multcell[0].name
                if cellname not in multlocs:
                    multlocs[cellname] = set()

                multlocs[cellname].add(phy_loc)

        # this map represents the mapping from input name to its inverter name
        self.inversionpins = {
            "LOGIC": {
                "TA1": "TAS1",
                "TA2": "TAS2",
                "TB1": "TBS1",
                "TB2": "TBS2",
                "BA1": "BAS1",
                "BA2": "BAS2",
                "BB1": "BBS1",
                "BB2": "BBS2",
                "QCK": "QCKS",
            }
        }

        # prepare helper structure for connections
        self.connections_by_loc = defaultdict(list)
        for connection in self.connections:
            self.connections_by_loc[connection.dst].append(connection)
            self.connections_by_loc[connection.src].append(connection)

        # a mapping from the type of cell FASM line refers to to its parser
        self.featureparsers = {
            "LOGIC": self.parse_logic_line,
            "QMUX": self.parse_logic_line,
            "GMUX": self.parse_logic_line,
            "INTERFACE": self.parse_interface_line,
            "ROUTING": self.parse_routing_line,
            "CAND0": self.parse_colclk_line,
            "CAND1": self.parse_colclk_line,
            "CAND2": self.parse_colclk_line,
            "CAND3": self.parse_colclk_line,
            "CAND4": self.parse_colclk_line,
            "RAM": self.parse_ram_line,
        }

        # a mapping from cell type to a set of possible pin names
        self.pinnames = defaultdict(set)
        for celltype in self.cells_library.values():
            typ = celltype.type
            for pin in celltype.pins:
                self.pinnames[typ].add(pin.name)

        # a mapping from cell types that occupy multiple locations
        # to a single location
        self.multiloccells = {"ASSP": MultiLocCellMapping("ASSP", assplocs, Loc(1, 1, 0), self.pinnames["ASSP"])}
        for ram in ramlocs:
            self.multiloccells[ram] = MultiLocCellMapping(
                ram, ramlocs[ram], list(ramlocs[ram])[0], self.pinnames["RAM"]
            )
        for mult in multlocs:
            self.multiloccells[mult] = MultiLocCellMapping(
                mult, multlocs[mult], list(multlocs[mult])[1], self.pinnames["MULT"]
            )

        # helper routing data
        self.routingdata = defaultdict(list)
        # a dictionary holding bit settings for BELs
        self.belinversions = defaultdict(lambda: defaultdict(list))
        # a dictionary holding bit settings for IOs
        self.interfaces = defaultdict(lambda: defaultdict(list))
        # a dictionary holding simplified connections between BELs
        self.designconnections = defaultdict(dict)
        # a dictionary holding hops from routing
        self.designhops = defaultdict(dict)

        # Clock column drivers (CAND) data
        self.colclk_data = defaultdict(lambda: defaultdict(list))
        # A map of clock wires that connect to switchboxes
        self.cand_map = defaultdict(lambda: dict())

        # A map of original (loc, pin) to new (loc, pin). Created during
        # aggregation of multi-loc cells.
        self.org_loc_map = {}

    def parse_logic_line(self, feature: Feature):
        """Parses a setting for a BEL.

        Parameters
        ----------
        feature: Feature
            FASM line for BEL
        """
        belname, setting = feature.signature.split(".", 1)
        if feature.value == 1:
            # FIXME handle ZINV pins
            if "ZINV." in setting:
                setting = setting.replace("ZINV.", "")
            elif "INV." in setting:
                setting = setting.replace("INV.", "")
            self.belinversions[feature.loc][belname].append(setting)

    def parse_interface_line(self, feature: Feature):
        """Parses a setting for IO.

        Parameters
        ----------
        feature: Feature
            FASM line for BEL
        """
        belname, setting = feature.signature.split(".", 1)
        if feature.value == 1:
            setting = setting.replace("ZINV.", "")
            setting = setting.replace("INV.", "")
            self.interfaces[feature.loc][belname].append(setting)

    def parse_routing_line(self, feature: Feature):
        """Parses a routing setting.

        Parameters
        ----------
        feature: Feature
            FASM line for BEL
        """
        match = re.match(r"^I_highway\.IM(?P<switch_id>[0-9]+)\.I_pg(?P<sel_id>[0-9]+)$", feature.signature)
        if match:
            typ = "HIGHWAY"
            stage_id = 3  # FIXME: Get HIGHWAY stage id from the switchbox def
            switch_id = int(match.group("switch_id"))
            mux_id = 0
            sel_id = int(match.group("sel_id"))
        match = re.match(
            r"^I_street\.Isb(?P<stage_id>[0-9])(?P<switch_id>[0-9])\.I_M(?P<mux_id>[0-9]+)\.I_pg(?P<sel_id>[0-9]+)$",  # noqa: E501
            feature.signature,
        )
        if match:
            typ = "STREET"
            stage_id = int(match.group("stage_id")) - 1
            switch_id = int(match.group("switch_id")) - 1
            mux_id = int(match.group("mux_id"))
            sel_id = int(match.group("sel_id"))
        self.routingdata[feature.loc].append(
            RouteEntry(typ=typ, stage_id=stage_id, switch_id=switch_id, mux_id=mux_id, sel_id=sel_id)
        )

    def parse_colclk_line(self, feature: Feature):
        self.colclk_data[feature.loc][feature.typ].append(feature)

    def parse_ram_line(self, feature: Feature):
        """Parses a RAM line.

        Parameters
        ----------
        feature: Feature
            FASM line for BEL
        """
        raise NotImplementedError("Parsing RAM FASM lines is not supported")

    def parse_fasm_lines(self, fasmlines):
        """Parses FASM lines.

        Parameters
        ----------
        fasmlines: list
            A list of FasmLine objects
        """

        loctyp = re.compile(r"^X(?P<x>[0-9]+)Y(?P<y>[0-9]+)\.(?P<type>[A-Z]+[0-4]?)\.(?P<signature>.*)$")  # noqa: E501

        for line in fasmlines:
            if not line.set_feature:
                continue
            match = loctyp.match(line.set_feature.feature)
            if not match:
                raise self.Fasm2BelsException(
                    f"FASM features have unsupported format:  {line.set_feature}"
                )  # noqa: E501
            loc = Loc(x=int(match.group("x")), y=int(match.group("y")), z=0)
            typ = match.group("type")
            feature = Feature(loc=loc, typ=typ, signature=match.group("signature"), value=line.set_feature.value)
            self.featureparsers[typ](feature)

    def decode_switchbox(self, switchbox, features):
        """Decodes all switchboxes to extract full connections' info.

        For every output, this method determines its input in the routing
        switchboxes. In this representation, an input and output can be either
        directly connected to a BEL, or to a hop wire.

        Parameters
        ----------
        switchbox: a Switchbox object from vpr_switchbox_types
        features: features regarding given switchbox

        Returns
        -------
        dict: a mapping from output pin to input pin for a given switchbox
        """
        # Group switchbox connections by destinationa
        conn_by_dst = defaultdict(set)
        for c in switchbox.connections:
            conn_by_dst[c.dst].add(c)

        # Prepare data structure
        mux_sel = {}
        for stage_id, stage in switchbox.stages.items():
            mux_sel[stage_id] = {}
            for switch_id, switch in stage.switches.items():
                mux_sel[stage_id][switch_id] = {}
                for mux_id, mux in switch.muxes.items():
                    mux_sel[stage_id][switch_id][mux_id] = None

        for feature in features:
            assert mux_sel[feature.stage_id][feature.switch_id][feature.mux_id] is None, feature  # noqa: E501
            mux_sel[feature.stage_id][feature.switch_id][feature.mux_id] = feature.sel_id  # noqa: E501

        def expand_mux(out_loc):
            """
            Expands a multiplexer output until a switchbox input is reached.
            Returns name of the input or None if not found.

            Parameters
            ----------
            out_loc: the last output location

            Returns
            -------
            str: None if input name not found, else string
            """

            # Get mux selection, If it is set to None then the mux is
            # not active
            sel = mux_sel[out_loc.stage_id][out_loc.switch_id][out_loc.mux_id]
            if sel is None:
                return None  # TODO can we return None?

            stage = switchbox.stages[out_loc.stage_id]
            switch = stage.switches[out_loc.switch_id]
            mux = switch.muxes[out_loc.mux_id]
            pin = mux.inputs[sel]

            if pin.name is not None:
                return pin.name

            inp_loc = SwitchboxPinLoc(
                stage_id=out_loc.stage_id,
                switch_id=out_loc.switch_id,
                mux_id=out_loc.mux_id,
                pin_id=sel,
                pin_direction=PinDirection.INPUT,
            )

            # Expand all "upstream" muxes that connect to the selected
            # input pin
            assert inp_loc in conn_by_dst, inp_loc
            for c in conn_by_dst[inp_loc]:
                inp = expand_mux(c.src)
                if inp is not None:
                    return inp

            # Nothing found
            return None  # TODO can we return None?

        # For each output pin of a switchbox determine to which input is it
        # connected to.
        routes = {}
        for out_pin in switchbox.outputs.values():
            out_loc = out_pin.locs[0]
            routes[out_pin.name] = expand_mux(out_loc)

        return routes

    def process_switchbox(self, loc, switchbox, features):
        """Processes all switchboxes and extract hops from connections.

        The function extracts final connections from inputs to outputs, and
        hops into separate structures for further processing.

        Parameters
        ----------
        loc: Loc
            location of the current switchbox
        switchbox: Switchbox
            a switchbox
        features: list
            list of features regarding given switchbox
        """
        routes = self.decode_switchbox(switchbox, features)
        for k, v in routes.items():
            if v is not None:
                if re.match("[VH][0-9][LRBT][0-9]", k):
                    self.designhops[Loc(loc.x, loc.y, 0)][k] = v
                else:
                    self.designconnections[loc][k] = v

    def resolve_hops(self):
        """Resolves remaining hop wires.

        It determines the absolute input for the given pin by resolving hop
        wires and adds those final connections to the design connections.
        """
        for loc, conns in self.designconnections.items():
            for pin, source in conns.items():
                hop = get_name_and_hop(source)
                tloc = loc
                while hop[1] is not None:
                    tloc = Loc(tloc[0] + hop[1][0], tloc[1] + hop[1][1], 0)
                    # in some cases BEL is distanced from a switchbox, in those
                    # cases the hop will not point to another hop. We should
                    # simply return the pin here in the correct location
                    if hop[0] in self.designhops[tloc]:
                        hop = get_name_and_hop(self.designhops[tloc][hop[0]])
                    else:
                        hop = (hop[0], None)
                self.designconnections[loc][pin] = (tloc, hop[0])

    def resolve_connections(self):
        """Resolves connections between BELs and IOs."""
        keys = sorted(self.routingdata.keys(), key=lambda loc: (loc.x, loc.y))
        for loc in keys:
            routingfeatures = self.routingdata[loc]

            if loc in self.vpr_switchbox_grid:
                typ = self.vpr_switchbox_grid[loc]
                switchbox = self.vpr_switchbox_types[typ]
                self.process_switchbox(loc, switchbox, routingfeatures)
        self.resolve_hops()

    def remap_multiloc_loc(self, loc, pinname=None, celltype=None):
        """Unifies coordinates of cells occupying multiple locations.

        Some cells, like ASSP, RAM or multipliers occupy multiple locations.
        This method groups bits and connections for those cells into a single
        artificial location.

        Parameters
        ----------
        loc: Loc
            The current location
        pinname: str
            The optional name of the pin (used to determine to which cell
            pin refers to)
        celltype: str
            The optional name of the cell type

        Returns
        -------
        Loc: the new location of the cell
        """
        finloc = loc
        for multiloc in self.multiloccells.values():
            if pinname is None or pinname in multiloc.pinnames or celltype == multiloc.typ:
                if loc in multiloc.fromlocset:
                    finloc = multiloc.toloc
                    break
        return finloc

    def resolve_multiloc_cells(self):
        """Groups cells that are scattered around multiple locations."""
        newbelinversions = defaultdict(lambda: defaultdict(list))
        newdesignconnections = defaultdict(dict)

        for bellockey, bellocpair in self.belinversions.items():
            for belloctype, belloc in bellocpair.items():
                if belloctype in self.multiloccells:
                    newbelinversions[self.remap_multiloc_loc(bellockey, celltype=belloctype)][belloctype].extend(belloc)
        self.belinversion = newbelinversions

        for loc, conns in self.designconnections.items():
            for pin, src in conns.items():
                dstloc = self.remap_multiloc_loc(loc, pinname=pin)
                srcloc = self.remap_multiloc_loc(src[0], pinname=src[1])

                if srcloc != src[0]:
                    k, v = ((srcloc, src[1]), src)
                    if k in self.org_loc_map:
                        assert v == self.org_loc_map[k], (k, self.org_loc_map[k], v)
                    self.org_loc_map[k] = v

                if dstloc != loc:
                    k, v = ((dstloc, pin), (loc, pin))
                    if k in self.org_loc_map:
                        assert v == self.org_loc_map[k], (k, self.org_loc_map[k], v)
                    self.org_loc_map[k] = v

                newdesignconnections[dstloc][pin] = (srcloc, src[1])
        self.designconnections = newdesignconnections

    def get_clock_for_gmux(self, gmux, loc):
        """Returns location of a CLOCK cell associated with the given GMUX
        cell. Returns None if not found

        Parameters
        ----------
        gmux: str
            The GMUX cell name
        loc: Loc
            The GMUX location

        Returns
        -------
        Loc: the new location of the cell or None
        """

        connections = [
            c for c in self.connections if c.src.type == ConnectionType.TILE and c.dst.type == ConnectionType.TILE
        ]
        for connection in connections:
            # Only to a GMUX at the given location
            dst = connection.dst
            if dst.loc != loc or "GMUX" not in dst.pin:
                continue

            # GMUX cells are named "GMUX<index>".
            cell, pin = dst.pin.split("_", maxsplit=1)
            match = re.match(r"GMUX(?P<idx>[0-9]+)", cell)
            if match is None:
                continue

            # Not the cell that we are looking for
            if cell != gmux:
                continue

            # We are only interested in the IP connection
            if pin != "IP":
                continue

            # Must go from CLOCK<n>.IC pin
            cell, pin = connection.src.pin.split("_", maxsplit=1)
            if not cell.startswith("CLOCK") or pin != "IC":
                continue

            # Return the source location
            return connection.src.loc

        # Not found
        return None

    def get_gmux_for_qmux(self, qmux, loc):
        """Returns a map of the given QMUX selection to driving GMUX cells.

        Parameters
        ----------
        qmux: str
            The QMUX cell name
        loc: Loc
            The QMUX location

        Returns
        -------
        Dict: A dict indexed by the selection index holding tuples with format:
            (loc, cell, pin)
        """

        sel_map = {}

        connections = [c for c in self.connections if c.dst.type == ConnectionType.CLOCK]
        for connection in connections:
            # Only to a QMUX at the given location
            dst = connection.dst
            if dst.loc != loc or "QMUX" not in dst.pin:
                continue

            # QMUX cells are named "QMUX_<quad><index>".
            cell, pin = dst.pin.split(".", maxsplit=1)
            match = re.match(r"QMUX_(?P<quad>[A-Z]+)(?P<idx>[0-9]+)", cell)
            if match is None:
                continue

            # This is not for the given QMUX
            qmux_idx = int(match.group("idx"))
            if qmux != "QMUX{}".format(qmux_idx):
                continue

            # Get the QCLKIN pin index. These are named "QCLKIN<index>"
            match = re.match(r"QCLKIN(?P<idx>[0-9]+)", pin)
            if match is None:
                continue
            qclkin_idx = int(match.group("idx"))

            # Get the source endpoint of the connection
            cell, pin = connection.src.pin.split("_", maxsplit=1)
            match = re.match(r"GMUX(?P<idx>[0-9]+)", cell)
            if match is None:
                continue
            gmux_idx = int(match.group("idx"))

            # Since fasm2bels uses physical database, it is not aware of
            # other QMUX inputs that QCLKIN0. Assume that the connection
            # found is to the QCLKIN0 pin and add QCLKIN1..2 to the map
            # as well.
            assert qclkin_idx == 0, connection

            # Make map entries
            for i in range(3):
                # Calculate GMUX index for QCLKIN<i> input of the QMUX
                idx = (gmux_idx + i) % 5

                # Add to the map
                sel_map[i] = (
                    connection.src.loc,
                    "GMUX{}".format(idx),
                    pin,
                )

        return sel_map

    def get_qmux_for_cand(self, cand, loc):
        """Returns a QMUX cell and its location that drives the given CAND
        cell.

        Parameters
        ----------
        cand: str
            The CAND cell name
        loc: Loc
            The CAND location

        Returns
        -------
        Tuple: A tuple holding (loc, cell)
        """

        connections = [c for c in self.connections if c.dst.type == ConnectionType.CLOCK]
        for connection in connections:
            # Only to a CAND at the given location
            # Note: Check also the row above. CAND cells are located in two
            # rows but with fasm features everything gets aligned to even rows
            dst = connection.dst
            if (dst.loc != loc and dst.loc != Loc(loc.x, loc.y - 1, loc.z)) or "CAND" not in dst.pin:
                continue

            # CAND cells are named "CAND<index>_<quad>_<column>".
            cell, pin = dst.pin.split(".", maxsplit=1)
            match = re.match(r"CAND(?P<idx>[0-9]+)_(?P<quad>[A-Z]+)_(?P<col>[0-9]+)", cell)
            if match is None:
                continue

            # This is not for the given CAND
            if cand != "CAND{}".format(match.group("idx")):
                continue

            # QMUX cells are named "QMUX_<quad><index>".
            cell, pin = connection.src.pin.split(".", maxsplit=1)
            match = re.match(r"QMUX_(?P<quad>[A-Z]+)(?P<idx>[0-9]+)", cell)
            if match is None:
                continue

            # Return the QMUX and its location
            return "QMUX{}".format(match.group("idx")), connection.src.loc

        # None found
        return None, None

    def resolve_gmux(self):
        """Resolves GMUX cells, updates the designconnections map. Also creates
        connections to CLOCK cells whenever necessary.

        Returns
        -------
        Dict: A map of GMUX names to their output wires
        """

        # Process GMUX
        gmux_map = dict()
        gmux_locs = [loc for loc, tile in self.vpr_tile_grid.items() if "GMUX" in tile.type]
        for loc in gmux_locs:
            # Group GMUX input pin connections by GMUX cell names
            gmux_connections = defaultdict(lambda: dict())
            for cell_pin, conn in self.designconnections[loc].items():
                if cell_pin.startswith("GMUX"):
                    cell, pin = cell_pin.split("_", maxsplit=1)
                    gmux_connections[cell][pin] = conn

            # Examine each GMUX config
            for gmux, connections in gmux_connections.items():
                # FIXME: Handle IS0 inversion (if any)

                # The IS0 pin has to be routed
                if "IS0" not in connections:
                    print("WARNING: Pin '{}.IS0' at '{}' is unrouted!".format(gmux, loc))
                    continue

                # TODO: For now support only static GMUX settings
                if connections["IS0"][1] not in ["GND", "VCC"]:
                    print("WARNING: Non-static GMUX selection (at '{}') not supported yet!".format(loc))
                    continue

                # Static selection
                sel = int(connections["IS0"][1] == "VCC")

                # IP selected
                if sel == 0:
                    # Create a global clock wire for the CLOCK pad
                    match = re.match(r"GMUX(?P<idx>[0-9]+)", gmux)
                    assert match is not None, gmux

                    idx = int(match.group("idx"))
                    wire = "CLK{}".format(idx)

                    # Get the clock pad location
                    clock_loc = self.get_clock_for_gmux(gmux, loc)
                    assert clock_loc is not None, gmux

                    # Check if the clock pad is enabled. If not then discard
                    # the GMUX
                    bel_features = []
                    for bel, features in self.interfaces.get(clock_loc, {}).items():
                        for feature in features:
                            bel_features.append("{}.{}".format(bel, feature))

                    if "ASSP.ASSPInvPortAlias" not in bel_features:
                        continue

                    # Connect it to the output wire of the GMUX
                    self.designconnections[clock_loc]["CLOCK0_IC"] = (None, wire)

                    # The GMUX is implicit. Remove all connections to it
                    self.designconnections[loc] = {
                        k: v for k, v in self.designconnections[loc].items() if not k.startswith(gmux)
                    }

                # IC selected
                else:
                    # Check if the IC pin has an active driver. If not then
                    # discard the mux.
                    if connections.get("IC", (None, None))[1] in [None, "GND", "VCC"]:
                        continue

                    # Create a wire for the GMUX output
                    wire = "{}_X{}Y{}".format(gmux, loc.x, loc.y)

                    # Remove the IS0 connection
                    del self.designconnections[loc]["{}_IS0".format(gmux)]

                    # Connect the output
                    self.designconnections[loc]["{}_IZ".format(gmux)] = (None, wire)

                # Store the wire
                gmux_map[gmux] = wire

        return gmux_map

    def resolve_qmux(self, gmux_map):
        """Resolves QMUX cells, updates the designconnections map.

        Parameters
        ----------
        gmux_map: Dict
            A map of QMUX cells to their GMUX driving wires.

        Returns
        -------
        Dict: A map of locations and QMUX names to their driving wires
        """

        # Process QMUX
        qmux_map = defaultdict(lambda: dict())
        qmux_locs = [loc for loc, tile in self.vpr_tile_grid.items() if "QMUX" in tile.type]
        for loc in qmux_locs:
            # Group QMUX input pin connections by QMUX cell names
            qmux_connections = defaultdict(lambda: dict())
            for cell_pin, conn in self.designconnections[loc].items():
                if cell_pin.startswith("QMUX"):
                    cell, pin = cell_pin.split("_", maxsplit=1)
                    qmux_connections[cell][pin] = conn

            # Examine each QMUX config
            for qmux, connections in qmux_connections.items():
                # FIXME: Handle IS0 and IS1 inversion (if any)

                # Both IS0 and IS1 must be routed to something
                if "IS0" not in connections:
                    print("WARNING: Pin '{}.IS0' at '{}' is unrouted!".format(qmux, loc))
                if "IS1" not in connections:
                    print("WARNING: Pin '{}.IS1' at '{}' is unrouted!".format(qmux, loc))

                if "IS0" not in connections or "IS1" not in connections:
                    continue

                # TODO: For now support only static QMUX settings
                if connections["IS0"][1] not in ["GND", "VCC"]:
                    print("WARNING: Non-static QMUX selection (at '{}') not supported yet!".format(loc))
                    continue
                if connections["IS1"][1] not in ["GND", "VCC"]:
                    print("WARNING: Non-static QMUX selection (at '{}') not supported yet!".format(loc))
                    continue

                # Get associated GMUXes
                sel_map = self.get_gmux_for_qmux(qmux, loc)

                # Static selection
                sel = int(connections["IS0"][1] == "VCC") * 2 + int(connections["IS1"][1] == "VCC")

                # Input from the routing network selected, create a new wire
                if sel == 3:
                    # Check if the HSCKIN input is connected to an active
                    # driver. If not then discard the QMUX
                    if connections.get("HSCKIN", (None, None))[1] in [None, "GND", "VCC"]:
                        continue

                    # Create a wire for the QMUX output
                    wire = "{}_X{}Y{}".format(qmux, loc.x, loc.y)

                    # Remove IS0 and IS1 from the connection map.
                    del self.designconnections[loc]["{}_IS0".format(qmux)]
                    del self.designconnections[loc]["{}_IS1".format(qmux)]

                    # Connect the output
                    self.designconnections[loc]["{}_IZ".format(qmux)] = (None, wire)

                # Input from a GMUX is selected, assign its wire here
                else:
                    # The GMUX is not active. Discard the QMUX
                    gmux_loc, gmux_cell, gmux_pin = sel_map[sel]
                    if gmux_cell not in gmux_map:
                        continue

                    # Use the wire of that GMUX
                    wire = gmux_map[gmux_cell]

                    # The QMUX is implicit. Remove all connections to it
                    self.designconnections[loc] = {
                        k: v for k, v in self.designconnections[loc].items() if not k.startswith(qmux)
                    }

                # Store the wire
                qmux_map[loc][qmux] = wire

        return dict(qmux_map)

    def resolve_cand(self, qmux_map):
        """Resolves CAND cells, creates the cand_map map.

        Parameters
        ----------
        qmux_map: Dict
            A map of locations and CAND names to their driving QMUXes.

        Returns
        -------
        None
        """

        # Process CAND
        for loc, all_features in self.colclk_data.items():
            for cand, features in all_features.items():
                hilojoint = False
                enjoint = False

                for feature in features:
                    if feature.signature == "I_hilojoint":
                        hilojoint = bool(feature.value)
                    if feature.signature == "I_enjoint":
                        enjoint = bool(feature.value)

                # TODO: Do not support dynamically enabled CANDs for now.
                assert enjoint is False, "Dynamically enabled CANDs are not supported yet"

                # Statically disabled, skip this one
                if hilojoint is False:
                    continue

                # Find a QMUX driving this CAND cell
                qmux_cell, qmux_loc = self.get_qmux_for_cand(cand, loc)
                assert qmux_cell is not None, (cand, loc)

                # The QMUX is not active, skip this one
                if qmux_loc not in qmux_map:
                    continue

                # Get the wire
                wire = qmux_map[qmux_loc][qmux_cell]

                # Populate the column clock to switchbox connection map
                quadrant = get_quadrant_for_loc(loc, self.quadrants)
                for y in range(quadrant.y0, quadrant.y1 + 1):
                    sb_loc = Loc(loc.x, y, 0)
                    self.cand_map[sb_loc][cand] = wire

    def resolve_global_clock_network(self):
        """Resolves the global clock network. Creates the cand_map, updates
        the designconnections.

        Returns
        -------
        None
        """

        # Resolve GMUXes
        gmux_map = self.resolve_gmux()
        # Resolve QMUXes
        qmux_map = self.resolve_qmux(gmux_map)
        # Resolve CANDs
        self.resolve_cand(qmux_map)

    def produce_verilog(self, pcf_data):
        """Produces string containing Verilog module representing FASM.

        Returns
        -------
        str, str: a Verilog module and PCF
        """

        module = VModule(
            self.vpr_tile_grid,
            self.vpr_tile_types,
            self.cells_library,
            pcf_data,
            self.belinversions,
            self.interfaces,
            self.designconnections,
            self.org_loc_map,
            self.cand_map,
            self.inversionpins,
            self.io_to_fbio,
        )
        module.parse_bels()
        verilog = module.generate_verilog()
        pcf = module.generate_pcf()
        qcf = module.generate_qcf()
        return verilog, pcf, qcf

    def convert_to_verilog(self, fasmlines):
        """Runs all methods required to convert FASM lines to Verilog module.

        Parameters
        ----------
        fasmlines: list
            FASM lines to process

        Returns
        -------
        str: a Verilog module
        """
        self.parse_fasm_lines(fasmlines)
        self.resolve_connections()
        self.resolve_multiloc_cells()
        self.resolve_global_clock_network()
        verilog, pcf, qcf = self.produce_verilog(pcf_data)
        return verilog, pcf, qcf


def parse_pcf(pcf):
    pcf_data = {}
    with open(pcf, "r") as fp:
        for line in fp:
            line = line.strip().split()
            if len(line) < 3:
                continue
            if len(line) > 3 and not line[3].startswith("#"):
                continue
            if line[0] != "set_io":
                continue
            pcf_data[line[2]] = line[1]
    return pcf_data


if __name__ == "__main__":
    # Parse arguments
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument("input_file", type=Path, help="Input fasm file")

    parser.add_argument("--phy-db", type=str, required=True, help="Physical device database file")

    parser.add_argument("--device-name", type=str, required=True, choices=["eos-s3", "pp3e"], help="Device name")

    parser.add_argument("--package-name", type=str, required=True, help="Device package name")

    parser.add_argument(
        "--input-type",
        type=str,
        choices=["bitstream", "fasm"],
        default="fasm",
        help="Determines whether the input is a FASM file or bitstream",
    )

    parser.add_argument("--output-verilog", type=Path, required=True, help="Output Verilog file")
    parser.add_argument(
        "--input-pcf", type=Path, required=False, help="Pins constraint file to maintain original pin names"
    )

    parser.add_argument("--output-pcf", type=Path, help="Output PCF file")
    parser.add_argument("--output-qcf", type=Path, help="Output QCF file")

    args = parser.parse_args()

    pcf_data = {}
    if args.input_pcf is not None:
        pcf_data = parse_pcf(args.input_pcf)

    # Load data from the database
    with open(args.phy_db, "rb") as fp:
        db = pickle.load(fp)

    # Initialize fasm2bels
    f2b = Fasm2Bels(db, args.device_name, args.package_name)

    # Disassemble bitstream / load FASM
    if args.input_type == "bitstream":
        qlfasmdb = load_quicklogic_database(get_db_dir("ql-" + args.device_name))

        if args.device_name == "eos-s3":
            assembler = QL732BAssembler(qlfasmdb)
        elif args.device_name == "pp3e":
            assembler = QL732BAssembler(qlfasmdb)  # Workaround: use EOS-S3 assembler for PP3E
        else:
            assert False, args.device_name

        assembler.read_bitstream(args.input_file)
        fasmlines = assembler.disassemble()
        fasmlines = [line for line in fasm.parse_fasm_string("\n".join(fasmlines))]

    else:
        fasmlines = [line for line in fasm.parse_fasm_filename(args.input_file)]

    # Run fasm2bels
    verilog, pcf, qcf = f2b.convert_to_verilog(fasmlines)

    # Write output files
    with open(args.output_verilog, "w") as outv:
        outv.write(verilog)

    if args.output_pcf:
        with open(args.output_pcf, "w") as outpcf:
            outpcf.write(pcf)
    if args.output_qcf:
        with open(args.output_qcf, "w") as outqcf:
            outqcf.write(qcf)
