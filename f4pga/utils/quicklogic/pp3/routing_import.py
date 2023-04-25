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

from lib.rr_graph import tracks
import lib.rr_graph.graph2 as rr
import lib.rr_graph_xml.graph2 as rr_xml
from lib import progressbar_utils

from f4pga.utils.quicklogic.pp3.data_structs import Loc, ConnectionType
from f4pga.utils.quicklogic.pp3.utils import fixup_pin_name

from f4pga.utils.quicklogic.pp3.rr_utils import add_node, add_track, add_edge, connect
from f4pga.utils.quicklogic.pp3.switchbox_model import SwitchboxModel, QmuxSwitchboxModel

# =============================================================================


def is_hop(connection):
    """
    Returns True if a connection represents a HOP wire.
    """

    if connection.src.type == ConnectionType.SWITCHBOX and connection.dst.type == ConnectionType.SWITCHBOX:
        return True

    return False


def is_tile(connection):
    """
    Rtturns True for connections going to/from tile.
    """

    if connection.src.type == ConnectionType.SWITCHBOX and connection.dst.type == ConnectionType.TILE:
        return True

    if connection.src.type == ConnectionType.TILE and connection.dst.type == ConnectionType.SWITCHBOX:
        return True

    return False


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


def is_clock(connection):
    """
    Returns True if the connection spans two clock cells
    """

    if connection.src.type == ConnectionType.CLOCK or connection.dst.type == ConnectionType.CLOCK:
        return True

    return False


def is_local(connection):
    """
    Returns true if a connection is local.
    """
    return (connection.src.loc.x, connection.src.loc.y) == (connection.dst.loc.x, connection.dst.loc.y)


# =============================================================================


def get_vpr_switch_for_clock_cell(graph, cell, src, dst):
    # Get a switch to model the mux delay properly. First try using
    # the cell name
    try:
        switch_name = "{}.{}.{}.{}".format(cell.type, cell.name, src, dst)
        switch_id = graph.get_switch_id(switch_name)
    except KeyError:
        # Not found, try using the cell type
        try:
            switch_name = "{}.{}.{}.{}".format(cell.type, cell.type, src, dst)
            switch_id = graph.get_switch_id(switch_name)
        except KeyError:
            # Still not found, use the generic one
            switch_id = graph.get_switch_id("generic")

            print("WARNING: No VPR switch found for '{}.{}' to '{}.{}'".format(cell.name, src, cell.name, dst))

    return switch_id


class QmuxModel(object):
    """
    A model of a QMUX cell implemented in the "route through" manner using
    RR nodes and edges.

    A QMUX has the following clock inputs
     - 0: QCLKIN0
     - 1: QCLKIN1
     - 2: QCLKIN2
     - 3: HSCKIN (from routing)

    The selection is controlled by a binary value of {IS1, IS0}. Both of the
    pins are connected to the switchbox.

    Since the QMUX is to be modelled using routing resources only, the part
    of the switchbox (of the whole switchbox) controlling the IS0 and IS1 pins
    will be removed. Appropriate fasm features will be attached to the edges
    that will model the QMUX. This will mimic the switchbox operation.

    The HSCKIN input is not modelled so the global clock network cannot be
    entered at a QMUX.
    """

    def __init__(self, graph, cell, phy_loc, switchbox_model, connections, node_map):
        self.graph = graph
        self.cell = cell
        self.phy_loc = phy_loc
        self.switchbox_model = switchbox_model

        self.connections = [c for c in connections if is_clock(c)]
        self.connection_loc_to_node = node_map

        self.ctrl_routes = {}

        self._build()

    def _build(self):
        """
        Builds the QMUX cell model
        """

        # Get routes for control pins
        self.ctrl_routes = self.switchbox_model.ctrl_routes[self.cell.name]

        # Check the routes, there has to be only one per const source
        for pin, pin_routes in self.ctrl_routes.items():
            for net in pin_routes.keys():
                assert len(pin_routes[net]) == 1, (self.cell.name, pin, net, pin_routes[net])
                pin_routes[net] = pin_routes[net][0]

        # Get segment id
        segment_id = self.graph.get_segment_id_from_name("clock")

        # Get the GMUX to QMUX connections
        nodes = {}
        for connection in self.connections:
            if connection.dst.type == ConnectionType.CLOCK:
                dst_cell, dst_pin = connection.dst.pin.split(".")

                if dst_cell == self.cell.name and dst_pin.startswith("QCLKIN"):
                    ep = connection.dst
                    try:
                        nodes[dst_pin] = self.connection_loc_to_node[ep]
                    except KeyError:
                        print("ERROR: Coulnd't find rr node for {}.{}".format(self.cell.name, pin))

        # Get the QMUX to CAND connection
        for connection in self.connections:
            if connection.src.type == ConnectionType.CLOCK:
                src_cell, src_pin = connection.src.pin.split(".")

                if src_cell == self.cell.name and src_pin == "IZ":
                    ep = connection.src
                    try:
                        nodes["IZ"] = self.connection_loc_to_node[ep]
                    except KeyError:
                        print("ERROR: Coulnd't find rr node for {}.{}".format(self.cell.name, pin))
        # Validate
        for pin in ["IZ", "QCLKIN0", "QCLKIN1", "QCLKIN2"]:
            if pin not in nodes:
                return

        # Add edges modelling the QMUX
        for i in [0, 1, 2]:
            pin = "QCLKIN{}".format(i)

            src_node = nodes[pin]
            dst_node = nodes["IZ"]

            # Make edge metadata
            metadata = self._get_metadata(i)

            if len(metadata):
                meta_name = "fasm_features"
                meta_value = "\n".join(metadata)
            else:
                meta_name = None
                meta_value = ""

            switch_id = get_vpr_switch_for_clock_cell(
                self.graph, self.cell, "QCLKIN0", "IZ"  # FIXME: Always use the QCLKIN0->IZ timing here
            )

            # Mux switch with appropriate timing and fasm metadata
            connect(
                self.graph,
                src_node,
                dst_node,
                switch_id=switch_id,
                segment_id=segment_id,
                meta_name=meta_name,
                meta_value=meta_value,
            )

    def _get_metadata(self, selection):
        """
        Formats fams metadata for the QMUX cell that enables the given QMUX
        input selection.
        """
        metadata = []

        # Map selection to {IS1, IS0}.
        # FIXME: Seems suspicious... Need to swap IS0 and IS1 ?
        SEL_TO_PINS = {
            0: {"IS1": "GND", "IS0": "GND"},
            1: {"IS1": "VCC", "IS0": "GND"},
            2: {"IS1": "GND", "IS0": "VCC"},
        }

        assert selection in SEL_TO_PINS, selection
        pins = SEL_TO_PINS[selection]

        # Format prefix
        prefix = "X{}Y{}.QMUX.QMUX".format(self.phy_loc.x, self.phy_loc.y)

        # Collect features
        for pin, net in pins.items():
            # Get switchbox routing features (already prefixed)
            for muxsel in self.ctrl_routes[pin][net]:
                stage_id, switch_id, mux_id, pin_id = muxsel
                stage = self.switchbox_model.switchbox.stages[stage_id]

                metadata += SwitchboxModel.get_metadata_for_mux(self.phy_loc, stage, switch_id, mux_id, pin_id)

        # These features control inverters on IS0 and IS1. The inverters
        # are not used hence they are always disabled.
        zinv_features = [
            "I_invblock.I_J0.ZINV.IS0",
            "I_invblock.I_J1.ZINV.IS1",
            "I_invblock.I_J2.ZINV.IS0",
            "I_invblock.I_J3.ZINV.IS0",
            "I_invblock.I_J4.ZINV.IS1",
        ]

        for f in zinv_features:
            feature = "{}.{}".format(prefix, f)
            metadata.append(feature)

        return metadata


class CandModel(object):
    """
    A model of a CAND cell implemented in the "route through" manner using
    RR nodes and edges.

    A CAND cell has aninput IC connected to QMUX via a dedicated route, an
    output connected to its clock column and a dynamic enable input EN
    connected to the routing network.

    We won't use the enable input EN so its not modelled in any way. The
    CAND cell is statically enabled or disabled via the bitstream. There is
    a single edge that models the cell with appropriate fasm features attached.
    """

    def __init__(self, graph, cell, phy_loc, connections, node_map, cand_node_map):
        self.graph = graph
        self.cell = cell
        self.phy_loc = phy_loc

        self.connections = [c for c in connections if is_clock(c)]
        self.connection_loc_to_node = node_map

        self.cand_node_map = cand_node_map

        self._build()

    def _build(self):
        # Get segment id
        segment_id = self.graph.get_segment_id_from_name("clock")

        # Get the CAND name
        cand_name = self.cell.name.split("_", maxsplit=1)[0]
        # Get the column clock entry node
        col_node = self.cand_node_map[cand_name][self.cell.loc]

        # Get the QMUX to CAND connection
        for connection in self.connections:
            if connection.dst.type == ConnectionType.CLOCK:
                dst_cell, dst_pin = connection.dst.pin.split(".")

                if dst_cell == self.cell.name and dst_pin == "IC":
                    ep = connection.dst
                    break
        else:
            print("ERROR: Coulnd't find rr node for {}.{}".format(self.cell.name, "IC"))
            return

        # Get the node for the connection destination
        row_node = self.connection_loc_to_node[ep]

        # Edge metadata that when used switches the CAND cell from the
        # "Static Disable" to "Static Enable" mode.
        metadata = self._get_metadata()

        if len(metadata):
            meta_name = "fasm_features"
            meta_value = "\n".join(metadata)
        else:
            meta_name = None
            meta_value = ""

        # Get switch
        switch_id = get_vpr_switch_for_clock_cell(self.graph, self.cell, "IC", "IZ")

        # Mux switch with appropriate timing and fasm metadata
        connect(
            self.graph,
            row_node,
            col_node,
            switch_id=switch_id,
            segment_id=segment_id,
            meta_name=meta_name,
            meta_value=meta_value,
        )

    def _get_metadata(self):
        """
        Formats a list of fasm features to be appended to the CAND modelling
        edge.
        """
        metadata = []

        # Format prefix
        prefix = "X{}Y{}".format(self.phy_loc.x, self.phy_loc.y)
        # Get the CAND name
        cand_name = self.cell.name.split("_", maxsplit=1)[0]

        # Format the final fasm line
        metadata.append("{}.{}.I_hilojoint".format(prefix, cand_name))
        return metadata


# =============================================================================


def get_node_id_for_tile_pin(graph, loc, tile_type, pin_name):
    """
    Returns a rr node associated with the given pin of the given tile type
    at the given location.
    """

    nodes = None

    # First try without the capacity prefix
    if loc.z == 0:
        rr_pin_name = "TL-{}.{}[0]".format(tile_type, fixup_pin_name(pin_name))

        try:
            nodes = graph.get_nodes_for_pin((loc.x, loc.y), rr_pin_name)
        except KeyError:
            pass

    # Didn't find, try with the capacity prefix
    if nodes is None:
        rr_pin_name = "TL-{}[{}].{}[0]".format(tile_type, loc.z, fixup_pin_name(pin_name))

        try:
            nodes = graph.get_nodes_for_pin((loc.x, loc.y), rr_pin_name)
        except KeyError:
            pass

    # Still not found.
    if nodes is None:
        return None

    # Got it
    assert len(nodes) == 1, (rr_pin_name, loc)
    return nodes[0][0]


def build_tile_pin_to_node_map(graph, nodes_by_id, tile_types, tile_grid):
    """
    Builds a map of tile pins (at given location!) to rr nodes.
    """

    node_map = {}

    # Build the map for each tile instance in the grid.
    for loc, tile in tile_grid.items():
        node_map[loc] = {}

        # Empty tiles do not have pins
        if tile is None:
            continue

        # For each pin of the tile
        for pin in tile_types[tile.type].pins:
            node_id = get_node_id_for_tile_pin(graph, loc, tile.type, pin.name)
            if node_id is None:
                print("WARNING: No node for pin '{}' at {}".format(pin.name, loc))
                continue

            # Convert to Node objects
            node = nodes_by_id[node_id]
            # Add to the map
            node_map[loc][pin.name] = node

    return node_map


def build_tile_connection_map(graph, nodes_by_id, tile_grid, connections):
    """
    Builds a map of connections to/from tiles and rr nodes.
    """
    node_map = {}

    # Adds entry to the map
    def add_to_map(conn_loc):
        tile = tile_grid.get(conn_loc.loc, None)
        if tile is None:
            print("WARNING: No tile for pin '{} at {}".format(conn_loc.pin, conn_loc.loc))
            return

        # Get the VPR rr node for the pin
        node_id = get_node_id_for_tile_pin(graph, conn_loc.loc, tile.type, conn_loc.pin)
        if node_id is None:
            print("WARNING: No node for pin '{}' at ({},{})".format(conn_loc.pin, conn_loc.loc.x, conn_loc.loc.y))
            return

        # Convert to Node objects
        node = nodes_by_id[node_id]
        # Add to the map
        node_map[conn_loc] = node

    # Look for connection endpoints that mention tiles
    endpoints = set([c.src for c in connections if c.src.type == ConnectionType.TILE])
    endpoints |= set([c.dst for c in connections if c.dst.type == ConnectionType.TILE])

    # Build the map
    for ep in endpoints:
        add_to_map(ep)

    return node_map


# =============================================================================


def add_l_track(graph, x0, y0, x1, y1, segment_id, switch_id):
    """
    Add a "L"-shaped track consisting of two channel nodes and a switch
    between the given two grid coordinates. The (x0, y0) determines source
    location and (x1, y1) destination (sink) location.

    Returns a tuple with indices of the first and last node.
    """
    dx = x1 - x0
    dy = y1 - y0

    assert dx != 0 or dy != 0, (x0, y0)

    nodes = [None, None]

    # Go vertically first
    if abs(dy) >= abs(dx):
        xc, yc = x0, y1

        if abs(dy):
            track = tracks.Track(
                direction="Y",
                x_low=min(x0, xc),
                x_high=max(x0, xc),
                y_low=min(y0, yc),
                y_high=max(y0, yc),
            )
            nodes[0] = add_track(graph, track, segment_id)

        if abs(dx):
            track = tracks.Track(
                direction="X",
                x_low=min(xc, x1),
                x_high=max(xc, x1),
                y_low=min(yc, y1),
                y_high=max(yc, y1),
            )
            nodes[1] = add_track(graph, track, segment_id)

    # Go horizontally first
    else:
        xc, yc = x1, y0

        if abs(dx):
            track = tracks.Track(
                direction="X",
                x_low=min(x0, xc),
                x_high=max(x0, xc),
                y_low=min(y0, yc),
                y_high=max(y0, yc),
            )
            nodes[0] = add_track(graph, track, segment_id)

        if abs(dy):
            track = tracks.Track(
                direction="Y",
                x_low=min(xc, x1),
                x_high=max(xc, x1),
                y_low=min(yc, y1),
                y_high=max(yc, y1),
            )
            nodes[1] = add_track(graph, track, segment_id)

    # In case of a horizontal or vertical only track make both nodes the same
    assert nodes[0] is not None or nodes[1] is not None

    if nodes[0] is None:
        nodes[0] = nodes[1]
    if nodes[1] is None:
        nodes[1] = nodes[0]

    # Add edge connecting the two nodes if needed
    if nodes[0].id != nodes[1].id:
        add_edge(graph, nodes[0].id, nodes[1].id, switch_id)

    return nodes


def add_track_chain(graph, direction, u, v0, v1, segment_id, switch_id):
    """
    Adds a chain of tracks that span the grid in the given direction.
    Returns the first and last node of the chain along with a map of
    coordinates to nodes.
    """
    node_by_v = {}
    prev_node = None

    # Make range generator
    if v0 > v1:
        coords = range(v0, v1 - 1, -1)
    else:
        coords = range(v0, v1 + 1)

    # Add track chain
    for v in coords:
        # Add track (node)
        if direction == "X":
            track = tracks.Track(
                direction=direction,
                x_low=v,
                x_high=v,
                y_low=u,
                y_high=u,
            )
        elif direction == "Y":
            track = tracks.Track(
                direction=direction,
                x_low=u,
                x_high=u,
                y_low=v,
                y_high=v,
            )
        else:
            assert False, direction

        curr_node = add_track(graph, track, segment_id)

        # Add edge from the previous one
        if prev_node is not None:
            add_edge(graph, prev_node.id, curr_node.id, switch_id)

        # No previous one, this is the first one
        else:
            start_node = curr_node

        node_by_v[v] = curr_node
        prev_node = curr_node

    return start_node, curr_node, node_by_v


def add_tracks_for_const_network(graph, const, tile_grid):
    """
    Builds a network of CHANX/CHANY and edges to propagate signal from a
    const source.

    The const network is purely artificial and does not correspond to any
    physical routing resources.

    Returns a map of const network nodes for each location.
    """

    # Get the tilegrid span
    xs = set([loc.x for loc in tile_grid])
    ys = set([loc.y for loc in tile_grid])
    xmin, ymin = min(xs), min(ys)
    xmax, ymax = max(xs), max(ys)

    # Get segment id and switch id
    segment_id = graph.get_segment_id_from_name(const.lower())
    switch_id = graph.get_delayless_switch_id()

    # Find the source tile
    src_loc = [loc for loc, t in tile_grid.items() if t is not None and t.type == "SYN_{}".format(const)]
    assert len(src_loc) == 1, const
    src_loc = src_loc[0]

    # Go down from the source to the edge of the tilegrid
    entry_node, col_node, _ = add_track_chain(graph, "Y", src_loc.x, src_loc.y, 1, segment_id, switch_id)

    # Connect the tile OPIN to the column
    pin_name = "TL-SYN_{const}.{const}0_{const}[0]".format(const=const)
    opin_node = graph.get_nodes_for_pin((src_loc[0], src_loc[1]), pin_name)
    assert len(opin_node) == 1, pin_name

    add_edge(graph, opin_node[0][0], entry_node.id, switch_id)

    # Got left and right from the source column over the bottommost row
    row_entry_node1, _, row_node_map1 = add_track_chain(graph, "X", 0, src_loc.x, 1, segment_id, switch_id)
    row_entry_node2, _, row_node_map2 = add_track_chain(graph, "X", 0, src_loc.x + 1, xmax - 1, segment_id, switch_id)

    # Connect rows to the column
    add_edge(graph, col_node.id, row_entry_node1.id, switch_id)
    add_edge(graph, col_node.id, row_entry_node2.id, switch_id)
    row_node_map = {**row_node_map1, **row_node_map2}

    row_node_map[0] = row_node_map[1]

    # For each column add one that spand over the entire grid height
    const_node_map = {}
    for x in range(xmin, xmax):
        # Add the column
        col_entry_node, _, col_node_map = add_track_chain(graph, "Y", x, ymin + 1, ymax - 1, segment_id, switch_id)

        # Add edge fom the horizontal row
        add_edge(graph, row_node_map[x].id, col_entry_node.id, switch_id)

        # Populate the const node map
        for y, node in col_node_map.items():
            const_node_map[Loc(x=x, y=y, z=0)] = node

    return const_node_map


def create_track_for_hop_connection(graph, connection):
    """
    Creates a HOP wire track for the given connection
    """

    # Determine whether the wire goes horizontally or vertically.
    if connection.src.loc.y == connection.dst.loc.y:
        direction = "X"
    elif connection.src.loc.x == connection.dst.loc.x:
        direction = "Y"
    else:
        assert False, connection

    assert connection.src.loc != connection.dst.loc, connection

    # Determine the connection length
    length = max(abs(connection.src.loc.x - connection.dst.loc.x), abs(connection.src.loc.y - connection.dst.loc.y))

    segment_name = "hop{}".format(length)

    # Add the track to the graph
    track = tracks.Track(
        direction=direction,
        x_low=min(connection.src.loc.x, connection.dst.loc.x),
        x_high=max(connection.src.loc.x, connection.dst.loc.x),
        y_low=min(connection.src.loc.y, connection.dst.loc.y),
        y_high=max(connection.src.loc.y, connection.dst.loc.y),
    )

    node = add_track(graph, track, graph.get_segment_id_from_name(segment_name))

    return node


# =============================================================================


def populate_hop_connections(graph, switchbox_models, connections):
    """
    Populates HOP connections
    """

    # Process connections
    bar = progressbar_utils.progressbar
    conns = [c for c in connections if is_hop(c)]
    for connection in bar(conns):
        # Get switchbox models
        src_switchbox_model = switchbox_models[connection.src.loc]
        dst_switchbox_model = switchbox_models[connection.dst.loc]

        # Get nodes
        src_node = src_switchbox_model.get_output_node(connection.src.pin)
        dst_node = dst_switchbox_model.get_input_node(connection.dst.pin)

        # Do not add the connection if one of the nodes is missing
        if src_node is None or dst_node is None:
            continue

        # Create the hop wire, use it as output node of the switchbox
        hop_node = create_track_for_hop_connection(graph, connection)

        # Connect
        connect(graph, src_node, hop_node)

        connect(graph, hop_node, dst_node)


def populate_tile_connections(graph, switchbox_models, connections, connection_loc_to_node):
    """
    Populates switchbox to tile and tile to switchbox connections
    """

    # Process connections
    bar = progressbar_utils.progressbar
    conns = [c for c in connections if is_tile(c)]
    for connection in bar(conns):
        # Connection to/from the local tile
        if is_local(connection):
            loc = connection.src.loc

            # No switchbox model at the loc, skip.
            if loc not in switchbox_models:
                continue

            # Get the switchbox model (both locs are the same)
            switchbox_model = switchbox_models[loc]

            # To tile
            if connection.dst.type == ConnectionType.TILE:
                if connection.dst not in connection_loc_to_node:
                    print("WARNING: No IPIN node for connection {}".format(connection))
                    continue

                tile_node = connection_loc_to_node[connection.dst]

                sbox_node = switchbox_model.get_output_node(connection.src.pin)
                if sbox_node is None:
                    continue

                connect(graph, sbox_node, tile_node)

            # From tile
            if connection.src.type == ConnectionType.TILE:
                if connection.src not in connection_loc_to_node:
                    print("WARNING: No OPIN node for connection {}".format(connection))
                    continue

                tile_node = connection_loc_to_node[connection.src]

                sbox_node = switchbox_model.get_input_node(connection.dst.pin)
                if sbox_node is None:
                    continue

                connect(graph, tile_node, sbox_node)

        # Connection to/from a foreign tile
        else:
            # Get segment id and switch id
            segment_id = graph.get_segment_id_from_name("special")
            switch_id = graph.get_delayless_switch_id()

            # Add a track connecting the two locations
            src_node, dst_node = add_l_track(
                graph,
                connection.src.loc.x,
                connection.src.loc.y,
                connection.dst.loc.x,
                connection.dst.loc.y,
                segment_id,
                switch_id,
            )

            # Connect the track
            eps = [connection.src, connection.dst]
            for i, ep in enumerate(eps):
                # Endpoint at tile
                if ep.type == ConnectionType.TILE:
                    # To tile
                    if ep == connection.dst:
                        if ep not in connection_loc_to_node:
                            print("WARNING: No IPIN node for connection {}".format(connection))
                            continue

                        node = connection_loc_to_node[ep]
                        connect(graph, dst_node, node, switch_id)

                    # From tile
                    elif ep == connection.src:
                        if ep not in connection_loc_to_node:
                            print("WARNING: No OPIN node for connection {}".format(connection))
                            continue

                        node = connection_loc_to_node[ep]
                        connect(graph, node, src_node, switch_id)

                # Endpoint at switchbox
                elif ep.type == ConnectionType.SWITCHBOX:
                    # No switchbox model at the loc, skip.
                    if ep.loc not in switchbox_models:
                        continue

                    # Get the switchbox model (both locs are the same)
                    switchbox_model = switchbox_models[ep.loc]

                    # To switchbox
                    if ep == connection.dst:
                        sbox_node = switchbox_model.get_input_node(ep.pin)
                        if sbox_node is None:
                            continue

                        connect(graph, dst_node, sbox_node)

                    # From switchbox
                    elif ep == connection.src:
                        sbox_node = switchbox_model.get_output_node(ep.pin)
                        if sbox_node is None:
                            continue

                        connect(graph, sbox_node, src_node)


def populate_direct_connections(graph, connections, connection_loc_to_node):
    """
    Populates all direct tile-to-tile connections.
    """

    # Process connections
    bar = progressbar_utils.progressbar
    conns = [c for c in connections if is_direct(c)]
    for connection in bar(conns):
        # Get segment id and switch id
        if connection.src.pin.startswith("CLOCK"):
            switch_id = graph.get_delayless_switch_id()

        else:
            switch_id = graph.get_delayless_switch_id()

        # Get tile nodes
        src_tile_node = connection_loc_to_node.get(connection.src, None)
        dst_tile_node = connection_loc_to_node.get(connection.dst, None)

        # Couldn't find at least one endpoint node
        if src_tile_node is None or dst_tile_node is None:
            if src_tile_node is None:
                print("WARNING: No OPIN node for direct connection {}".format(connection))

            if dst_tile_node is None:
                print("WARNING: No IPIN node for direct connection {}".format(connection))

            continue

        # Add the edge
        add_edge(graph, src_tile_node.id, dst_tile_node.id, switch_id)


def populate_const_connections(graph, switchbox_models, tile_types, tile_grid, tile_pin_to_node, const_node_map):
    """
    Connects switchbox inputs that represent VCC and GND constants to
    nodes of the global const network.

    Also connect FAKE_CONST pins of tiles directly to the global const network.
    """

    bar = progressbar_utils.progressbar

    # Connect the global const network to switchbox inputs
    for loc, switchbox_model in bar(switchbox_models.items()):
        # Look for input connected to a const
        for pin in switchbox_model.switchbox.inputs.values():
            # Got a const input
            if pin.name in const_node_map:
                const_node = const_node_map[pin.name][loc]

                sbox_node = switchbox_model.get_input_node(pin.name)
                if sbox_node is None:
                    continue

                connect(
                    graph,
                    const_node,
                    sbox_node,
                )

    # Add edges from the global const network to FAKE_CONST pins of tiles
    # that bypass the switchbox.
    switch_id = graph.get_switch_id("generic")

    for loc, tile in bar(tile_grid.items()):
        if tile is None:
            continue

        tile_type = tile_types[tile.type]
        if tile_type.fake_const_pin:
            tile_node = tile_pin_to_node[loc]["FAKE_CONST"]

            for const in ["GND", "VCC"]:
                const_node = const_node_map[const][loc]
                connect(graph, const_node, tile_node, switch_id=switch_id)


def populate_cand_connections(graph, switchbox_models, cand_node_map):
    """
    Populates global clock network to switchbox connections. These all the
    CANDn inputs of a switchbox.
    """

    bar = progressbar_utils.progressbar
    for loc, switchbox_model in bar(switchbox_models.items()):
        # Look for input connected to a CAND
        for pin in switchbox_model.switchbox.inputs.values():
            # Got a CAND input
            if pin.name in cand_node_map:
                cand_node = cand_node_map[pin.name][loc]

                sbox_node = switchbox_model.get_input_node(pin.name)
                if sbox_node is None:
                    continue

                connect(
                    graph,
                    cand_node,
                    sbox_node,
                )


# =============================================================================


def create_quadrant_clock_tracks(graph, connections, connection_loc_to_node):
    """
    Creates tracks representing global clock network routes namely all
    connections between GMUXes and QMUXes as well as QMUXes to CANDs.
    """

    node_map = {}

    # Get segment id and switch id
    segment_id = graph.get_segment_id_from_name("clock")
    switch_id = graph.get_delayless_switch_id()

    # Process connections
    bar = progressbar_utils.progressbar
    conns = [c for c in connections if is_clock(c)]
    for connection in bar(conns):
        # Source is a tile
        if connection.src.type == ConnectionType.TILE:
            src_node = connection_loc_to_node.get(connection.src, None)
            if src_node is None:
                print("WARNING: No OPIN node for clock connection {}".format(connection))
                continue

        # Source is a switchbox. Skip as control inputs of CAND and QMUX are
        # not to be routed to a switchbox.
        elif connection.src.type == ConnectionType.SWITCHBOX:
            continue

        # Source is another global clock cell, do not connect it anywhere now.
        elif connection.src.type == ConnectionType.CLOCK:
            src_node = None

        else:
            assert False, connection

        # Destination is a tile
        if connection.dst.type == ConnectionType.TILE:
            dst_node = connection_loc_to_node.get(connection.dst, None)
            if dst_node is None:
                print("WARNING: No IPIN node for clock connection {}".format(connection))
                continue

        # Destination is another global clock cell, do not connect it anywhere
        # now.
        elif connection.dst.type == ConnectionType.CLOCK:
            dst_node = None

        else:
            assert False, connection

        # Add a track connecting the two locations
        # Some CAND cells share the same physical location as QMUX cells.
        # In that case add a single "jump" node
        if connection.src.loc == connection.dst.loc:
            src_track_node = add_node(graph, connection.src.loc, "X", segment_id)
            dst_track_node = src_track_node

        else:
            src_track_node, dst_track_node = add_l_track(
                graph,
                connection.src.loc.x,
                connection.src.loc.y,
                connection.dst.loc.x,
                connection.dst.loc.y,
                segment_id,
                switch_id,
            )

        # Connect the OPIN
        if src_node is not None:
            connect(graph, src_node, src_track_node)

        # Add to the node map.
        else:
            ep = connection.src

            # If not already there, add it
            if ep not in node_map:
                node_map[ep] = src_track_node

            # Add a connection to model the fan-out
            else:
                connect(graph, node_map[ep], src_track_node)

        # Connect the IPIN
        if dst_node is not None:
            connect(graph, dst_track_node, dst_node)

        # Add to the node map. Since this is a destination there cannot be any
        # fan-in.
        else:
            ep = connection.dst
            assert ep not in node_map, ep
            node_map[ep] = dst_track_node

    return node_map


def create_column_clock_tracks(graph, clock_cells, quadrants):
    """
    This function adds tracks for clock column routes. It returns a map of
    "assess points" to that tracks to be used by switchbox connections.
    """

    CAND_RE = re.compile(r"^(?P<name>CAND[0-4])_(?P<quad>[A-Z]+)_(?P<col>[0-9]+)$")

    # Get segment id and switch id
    segment_id = graph.get_segment_id_from_name("clock")
    switch_id = graph.get_delayless_switch_id()

    # Process CAND cells
    cand_node_map = {}

    for cell in clock_cells.values():
        # A clock column is defined by a CAND cell
        if cell.type != "CAND":
            continue

        # Get index and quadrant
        match = CAND_RE.match(cell.name)
        if not match:
            continue

        cand_name = match.group("name")
        cand_quad = match.group("quad")

        quadrant = quadrants[cand_quad]

        # Add track chains going upwards and downwards from the CAND cell
        up_entry_node, _, up_node_map = add_track_chain(
            graph, "Y", cell.loc.x, cell.loc.y, quadrant.y0, segment_id, switch_id
        )
        dn_entry_node, _, dn_node_map = add_track_chain(
            graph, "Y", cell.loc.x, cell.loc.y + 1, quadrant.y1, segment_id, switch_id
        )

        # Connect entry nodes
        cand_entry_node = up_entry_node
        add_edge(graph, cand_entry_node.id, dn_entry_node.id, switch_id)

        # Join node maps
        node_map = {**up_node_map, **dn_node_map}

        # Populate the global clock network to switchbox access map
        for y, node in node_map.items():
            loc = Loc(x=cell.loc.x, y=y, z=0)

            if cand_name not in cand_node_map:
                cand_node_map[cand_name] = {}

            cand_node_map[cand_name][loc] = node

    return cand_node_map


# =============================================================================


def yield_edges(edges):
    """
    Yields edges in a format acceptable by the graph serializer.
    """
    conns = set()

    # Process edges
    for edge in edges:
        # Reformat metadata
        if edge.metadata:
            metadata = [(meta.name, meta.value) for meta in edge.metadata]
        else:
            metadata = None

        # Check for repetition
        if (edge.src_node, edge.sink_node) in conns:
            print(
                "WARNING: Removing duplicated edge from {} to {}, metadata='{}'".format(
                    edge.src_node, edge.sink_node, metadata
                )
            )
            continue

        conns.add((edge.src_node, edge.sink_node))

        # Yield the edge
        yield (edge.src_node, edge.sink_node, edge.switch_id, metadata)


# =============================================================================


def main():
    # Parse arguments
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument("--vpr-db", type=str, required=True, help="VPR database file")
    parser.add_argument("--rr-graph-in", type=str, required=True, help="Input RR graph XML file")
    parser.add_argument(
        "--rr-graph-out", type=str, default="rr_graph.xml", help="Output RR graph XML file (def. rr_graph.xml)"
    )

    args = parser.parse_args()

    # Load data from the database
    print("Loading database...")
    with open(args.vpr_db, "rb") as fp:
        db = pickle.load(fp)

        vpr_quadrants = db["vpr_quadrants"]
        vpr_clock_cells = db["vpr_clock_cells"]
        loc_map = db["loc_map"]
        vpr_tile_types = db["vpr_tile_types"]
        vpr_tile_grid = db["vpr_tile_grid"]
        vpr_switchbox_types = db["vpr_switchbox_types"]
        vpr_switchbox_grid = db["vpr_switchbox_grid"]
        connections = db["connections"]
        switches = db["switches"]

    # Load the routing graph, build SOURCE -> OPIN and IPIN -> SINK edges.
    print("Loading rr graph...")
    xml_graph = rr_xml.Graph(
        input_file_name=args.rr_graph_in, output_file_name=args.rr_graph_out, progressbar=progressbar_utils.progressbar
    )

    # Add back the switches that were unused in the arch.xml and got pruned
    # byt VPR.
    for switch in switches:
        try:
            xml_graph.graph.get_switch_id(switch.name)
            continue
        except KeyError:
            xml_graph.add_switch(
                rr.Switch(
                    id=None,
                    name=switch.name,
                    type=rr.SwitchType[switch.type.upper()],
                    timing=rr.SwitchTiming(
                        r=switch.r,
                        c_in=switch.c_in,
                        c_out=switch.c_out,
                        c_internal=switch.c_int,
                        t_del=switch.t_del,
                    ),
                    sizing=rr.SwitchSizing(
                        mux_trans_size=0,
                        buf_size=0,
                    ),
                )
            )

    print("Building maps...")

    # Add a switch map to the graph
    switch_map = {}
    for switch in xml_graph.graph.switches:
        assert switch.id not in switch_map, switch
        switch_map[switch.id] = switch

    xml_graph.graph.switch_map = switch_map

    # Build node id to node map
    nodes_by_id = {node.id: node for node in xml_graph.graph.nodes}

    # Build tile pin names to rr node ids map
    tile_pin_to_node = build_tile_pin_to_node_map(xml_graph.graph, nodes_by_id, vpr_tile_types, vpr_tile_grid)

    # Add const network
    const_node_map = {}
    for const in ["VCC", "GND"]:
        m = add_tracks_for_const_network(xml_graph.graph, const, vpr_tile_grid)
        const_node_map[const] = m

    # Connection loc (endpoint) to node map. Map ConnectionLoc objects to VPR
    # rr graph node ids.
    connection_loc_to_node = {}

    # Build a map of connections to/from tiles and rr nodes. The map points
    # to an IPIN/OPIN node for a connection loc that mentions it.
    node_map = build_tile_connection_map(xml_graph.graph, nodes_by_id, vpr_tile_grid, connections)
    connection_loc_to_node.update(node_map)

    # Build the global clock network
    print("Building the global clock network...")

    # GMUX to QMUX and QMUX to CAND tracks
    node_map = create_quadrant_clock_tracks(xml_graph.graph, connections, connection_loc_to_node)
    connection_loc_to_node.update(node_map)

    # Clock column tracks
    cand_node_map = create_column_clock_tracks(xml_graph.graph, vpr_clock_cells, vpr_quadrants)

    # Add switchbox models.
    print("Building switchbox models...")
    switchbox_models = {}

    # Gather QMUX cells
    qmux_cells = {}
    for cell in vpr_clock_cells.values():
        if cell.type == "QMUX":
            loc = cell.loc

            if loc not in qmux_cells:
                qmux_cells[loc] = {}

            qmux_cells[loc][cell.name] = cell

    # Create the models
    for loc, type in vpr_switchbox_grid.items():
        phy_loc = loc_map.bwd[loc]

        # QMUX switchbox model
        if loc in qmux_cells:
            switchbox_models[loc] = QmuxSwitchboxModel(
                graph=xml_graph.graph,
                loc=loc,
                phy_loc=phy_loc,
                switchbox=vpr_switchbox_types[type],
                qmux_cells=qmux_cells[loc],
                connections=[c for c in connections if is_clock(c)],
            )

        # Regular switchbox model
        else:
            switchbox_models[loc] = SwitchboxModel(
                graph=xml_graph.graph,
                loc=loc,
                phy_loc=phy_loc,
                switchbox=vpr_switchbox_types[type],
            )

    # Build switchbox models
    for switchbox_model in progressbar_utils.progressbar(switchbox_models.values()):
        switchbox_model.build()

    # Build the global clock network cell models
    print("Building QMUX and CAND models...")

    # Add QMUX and CAND models
    for cell in progressbar_utils.progressbar(vpr_clock_cells.values()):
        phy_loc = loc_map.bwd[cell.loc]

        if cell.type == "QMUX":
            QmuxModel(
                graph=xml_graph.graph,
                cell=cell,
                phy_loc=phy_loc,
                switchbox_model=switchbox_models[cell.loc],
                connections=connections,
                node_map=connection_loc_to_node,
            )

        if cell.type == "CAND":
            CandModel(
                graph=xml_graph.graph,
                cell=cell,
                phy_loc=phy_loc,
                connections=connections,
                node_map=connection_loc_to_node,
                cand_node_map=cand_node_map,
            )

    # Populate connections to the switchbox models
    print("Populating connections...")
    populate_hop_connections(xml_graph.graph, switchbox_models, connections)
    populate_tile_connections(xml_graph.graph, switchbox_models, connections, connection_loc_to_node)
    populate_direct_connections(xml_graph.graph, connections, connection_loc_to_node)
    populate_cand_connections(xml_graph.graph, switchbox_models, cand_node_map)
    populate_const_connections(
        xml_graph.graph, switchbox_models, vpr_tile_types, vpr_tile_grid, tile_pin_to_node, const_node_map
    )

    # Create channels from tracks
    pad_segment_id = xml_graph.graph.get_segment_id_from_name("pad")
    channels_obj = xml_graph.graph.create_channels(pad_segment=pad_segment_id)

    # Remove padding channels
    print("Removing padding nodes...")
    xml_graph.graph.nodes = [n for n in xml_graph.graph.nodes if n.capacity > 0]

    # Build node id to node map again since there have been new nodes added.
    nodes_by_id = {node.id: node for node in xml_graph.graph.nodes}

    # Sanity check edges
    print("Sanity checking edges...")
    node_ids = set([n.id for n in xml_graph.graph.nodes])
    for edge in xml_graph.graph.edges:
        assert edge.src_node in node_ids, edge
        assert edge.sink_node in node_ids, edge
        assert edge.src_node != edge.sink_node, edge

    # Sanity check IPIN/OPIN connections. There must be no tile completely
    # disconnected from the routing network
    print("Sanity checking tile connections...")

    connected_locs = set()
    for edge in xml_graph.graph.edges:
        src = nodes_by_id[edge.src_node]
        dst = nodes_by_id[edge.sink_node]

        if src.type == rr.NodeType.OPIN:
            loc = (src.loc.x_low, src.loc.y_low)
            connected_locs.add(loc)

        if dst.type == rr.NodeType.IPIN:
            loc = (src.loc.x_low, src.loc.y_low)
            connected_locs.add(loc)

    non_empty_locs = set((loc.x, loc.y) for loc in xml_graph.graph.grid if loc.block_type_id > 0)

    unconnected_locs = non_empty_locs - connected_locs
    for loc in unconnected_locs:
        block_type = xml_graph.graph.block_type_at_loc(loc)
        print(" ERROR: Tile '{}' at ({}, {}) is not connected!".format(block_type, loc[0], loc[1]))

    # Write the routing graph
    nodes_obj = xml_graph.graph.nodes
    edges_obj = xml_graph.graph.edges

    print("Serializing the rr graph...")
    xml_graph.serialize_to_xml(
        channels_obj=channels_obj,
        nodes_obj=nodes_obj,
        edges_obj=yield_edges(edges_obj),
        node_remap=lambda x: x,
    )


# =============================================================================

if __name__ == "__main__":
    main()
