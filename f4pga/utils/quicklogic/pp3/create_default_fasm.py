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
This utility generates a FASM file with a default bitstream configuration for
the given device.
"""
import argparse
import colorsys
from enum import Enum

import lxml.etree as ET

from f4pga.utils.quicklogic.pp3.data_structs import PinDirection, SwitchboxPinType
from f4pga.utils.quicklogic.pp3.data_import import import_data
from f4pga.utils.quicklogic.pp3.utils import yield_muxes
from f4pga.utils.quicklogic.pp3.switchbox_model import SwitchboxModel

# =============================================================================
duplicate = {}


class SwitchboxConfigBuilder:
    """
    This class is responsible for routing a switchbox according to the
    requested parameters and writing FASM features that configure it.
    """

    class NodeType(Enum):
        MUX = 0
        SOURCE = 1
        SINK = 2

    class Node:
        """
        Represents a graph node that corresponds either to a switchbox mux
        output or to a virtual source / sink node.
        """

        def __init__(self, type, key):
            self.type = type
            self.key = key

            # Current "net"
            self.net = None

            # Mux input ids indexed by keys and mux selection
            self.inp = {}
            self.sel = None

            # Mux inputs driven by this node as keys
            self.out = set()

    def __init__(self, switchbox):
        self.switchbox = switchbox
        self.nodes = {}

        # Build nodes representing the switchbox connectivity graph
        self._build_nodes()

    def _build_nodes(self):
        """
        Creates all nodes for routing.
        """

        # Create all mux nodes
        for stage, switch, mux in yield_muxes(self.switchbox):

            # Create the node
            key = (stage.id, switch.id, mux.id)
            node = self.Node(self.NodeType.MUX, key)

            # Store the node
            if stage.type not in self.nodes:
                self.nodes[stage.type] = {}

            assert node.key not in self.nodes[stage.type], (stage.type, node.key)
            self.nodes[stage.type][node.key] = node

        # Create all source and sink nodes, populate their connections with mux
        # nodes.
        for pin in self.switchbox.pins:

            # Node type
            if pin.direction == PinDirection.INPUT:
                node_type = self.NodeType.SOURCE
            elif pin.direction == PinDirection.OUTPUT:
                node_type = self.NodeType.SINK
            else:
                assert False, node_type

            # Create one for each stage type
            stage_ids = set([loc.stage_id for loc in pin.locs])
            for stage_id in stage_ids:

                # Create the node
                key = pin.name
                node = self.Node(node_type, key)

                # Initially annotate source nodes with net names
                if node.type == self.NodeType.SOURCE:
                    node.net = pin.name

                # Get the correct node list
                stage_type = self.switchbox.stages[stage_id].type
                assert stage_type in self.nodes, stage_type
                nodes = self.nodes[stage_type]

                # Add the node
                assert node.key not in self.nodes, node.key
                nodes[node.key] = node

            # Populate connections
            for pin_loc in pin.locs:

                # Get the correct node list
                stage_type = self.switchbox.stages[pin_loc.stage_id].type
                assert stage_type in self.nodes, stage_type
                nodes = self.nodes[stage_type]

                if pin.direction == PinDirection.INPUT:

                    # Get the mux node
                    key = (pin_loc.stage_id, pin_loc.switch_id, pin_loc.mux_id)
                    assert key in nodes, key
                    node = nodes[key]

                    key = (self.switchbox.type, pin_loc.stage_id, pin_loc.switch_id, pin_loc.mux_id)
                    if (
                        key in duplicate  # Mux has multiple inputs selected
                        and (pin_loc.pin_id in duplicate[key])  # Current selection is duplicate
                        and not (key[0].startswith("SB_TOP_IFC"))
                    ):  # Ignore TOP switchboxes
                        print("Warning: duplicate: {} - {}".format(key, pin_loc.pin_id))
                        continue

                    # Append reference to the input pin to the node
                    key = pin.name
                    assert key == "GND" or key not in node.inp, key
                    node.inp[key] = pin_loc.pin_id

                    # Get the SOURCE node
                    key = pin.name
                    assert key in nodes, key
                    node = nodes[key]

                    # Append the mux node as a sink
                    key = (pin_loc.stage_id, pin_loc.switch_id, pin_loc.mux_id)
                    node.out.add(key)

                elif pin.direction == PinDirection.OUTPUT:

                    # Get the sink node
                    key = pin.name
                    assert key in nodes, key
                    node = nodes[key]
                    assert node.type == self.NodeType.SINK

                    # Append reference to the mux
                    key = (pin_loc.stage_id, pin_loc.switch_id, pin_loc.mux_id)
                    node.inp[key] = 0

                    # Get the mux node
                    key = (pin_loc.stage_id, pin_loc.switch_id, pin_loc.mux_id)
                    assert key in nodes, key
                    node = nodes[key]

                    # Append the sink as the mux sink
                    key = pin.name
                    node.out.add(key)

                else:
                    assert False, pin.direction

        # Populate mux to mux connections
        for conn in self.switchbox.connections:

            # Get the correct node list
            stage_type = self.switchbox.stages[conn.dst.stage_id].type
            assert stage_type in self.nodes, stage_type
            nodes = self.nodes[stage_type]

            # Get the node
            key = (conn.dst.stage_id, conn.dst.switch_id, conn.dst.mux_id)
            assert key in nodes, key
            node = nodes[key]

            # Add its input and pin index
            key = (conn.src.stage_id, conn.src.switch_id, conn.src.mux_id)
            node.inp[key] = conn.dst.pin_id

            # Get the source node
            key = (conn.src.stage_id, conn.src.switch_id, conn.src.mux_id)
            assert key in nodes, key
            node = nodes[key]

            # Add the destination node to its outputs
            key = (conn.dst.stage_id, conn.dst.switch_id, conn.dst.mux_id)
            node.out.add(key)

    def stage_inputs(self, stage_type):
        """
        Yields inputs of the given stage type
        """
        assert stage_type in self.nodes, stage_type
        for node in self.nodes[stage_type].values():
            if node.type == self.NodeType.SOURCE:
                yield node.key

    def stage_outputs(self, stage_type):
        """
        Yields outputs of the given stage type
        """
        assert stage_type in self.nodes, stage_type
        for node in self.nodes[stage_type].values():
            if node.type == self.NodeType.SINK:
                yield node.key

    def propagate_input(self, stage_type, input_name):
        """
        Recursively propagates a net from an input pin to all reachable
        mux / sink nodes.
        """

        # Get the correct node list
        assert stage_type in self.nodes, stage_type
        nodes = self.nodes[stage_type]

        def walk(node):

            # Examine all driven nodes
            for sink_key in node.out:
                assert sink_key in nodes, sink_key
                sink_node = nodes[sink_key]

                # The sink is free
                if sink_node.net is None:

                    # Assign it to the net
                    sink_node.net = node.net
                    if sink_node.type == self.NodeType.MUX:
                        sink_node.sel = sink_node.inp[node.key]

                    # Expand
                    walk(sink_node)

        # Find the source node
        assert input_name in nodes, input_name
        node = nodes[input_name]

        # Walk downstream
        node.net = input_name
        walk(node)

    def ripup(self, stage_type):
        """
        Rips up all routes within the given stage
        """
        assert stage_type in self.nodes, stage_type
        for node in self.nodes[stage_type].values():
            if node.type != self.NodeType.SOURCE:
                node.net = None
                node.sel = None

    def check_nodes(self):
        """
        Check if all mux nodes have their selections set
        """
        result = True

        for stage_type, nodes in self.nodes.items():
            for key, node in nodes.items():

                if node.type == self.NodeType.MUX and node.sel is None:
                    result = False
                    print("WARNING: mux unconfigured", key)

        return result

    def fasm_features(self, loc):
        """
        Returns a list of FASM lines that correspond to the routed switchbox
        configuration.
        """
        lines = []

        for stage_type, nodes in self.nodes.items():
            for key, node in nodes.items():

                # For muxes with active selection
                if node.type == self.NodeType.MUX and node.sel is not None:
                    stage_id, switch_id, mux_id = key

                    # Get FASM features using the switchbox model.
                    features = SwitchboxModel.get_metadata_for_mux(
                        loc, self.switchbox.stages[stage_id], switch_id, mux_id, node.sel
                    )
                    lines.extend(features)

        return lines

    def dump_dot(self):
        """
        Dumps a routed switchbox visualization into Graphviz format for
        debugging purposes.
        """
        dot = []

        def key2str(key):
            if isinstance(key, str):
                return key
            else:
                return "st{}_sw{}_mx{}".format(*key)

        def fixup_label(lbl):
            lbl = lbl.replace("[", "(").replace("]", ")")

        # All nets
        nets = set()
        for nodes in self.nodes.values():
            for node in nodes.values():
                if node.net is not None:
                    nets.add(node.net)

        # Net colors
        node_colors = {None: "#C0C0C0"}
        edge_colors = {None: "#000000"}

        nets = sorted(list(nets))
        for i, net in enumerate(nets):

            hue = i / len(nets)
            light = 0.33
            saturation = 1.0

            r, g, b = colorsys.hls_to_rgb(hue, light, saturation)
            color = "#{:02X}{:02X}{:02X}".format(
                int(r * 255.0),
                int(g * 255.0),
                int(b * 255.0),
            )

            node_colors[net] = color
            edge_colors[net] = color

        # Add header
        dot.append("digraph {} {{".format(self.switchbox.type))
        dot.append('  graph [nodesep="1.0", ranksep="20"];')
        dot.append('  splines = "false";')
        dot.append("  rankdir = LR;")
        dot.append("  margin = 20;")
        dot.append("  node [style=filled];")

        # Stage types
        for stage_type, nodes in self.nodes.items():

            # Stage header
            dot.append('  subgraph "cluster_{}" {{'.format(stage_type))
            dot.append("    label=\"Stage '{}'\";".format(stage_type))

            # Nodes and internal mux edges
            for key, node in nodes.items():

                # Source node
                if node.type == self.NodeType.SOURCE:
                    name = "{}_inp_{}".format(stage_type, key2str(key))
                    label = key
                    color = node_colors[node.net]

                    dot.append(
                        '  "{}" [shape=octagon label="{}" fillcolor="{}"];'.format(
                            name,
                            label,
                            color,
                        )
                    )

                # Sink node
                elif node.type == self.NodeType.SINK:
                    name = "{}_out_{}".format(stage_type, key2str(key))
                    label = key
                    color = node_colors[node.net]

                    dot.append(
                        '  "{}" [shape=octagon label="{}" fillcolor="{}"];'.format(
                            name,
                            label,
                            color,
                        )
                    )

                # Mux node
                elif node.type == self.NodeType.MUX:
                    name = "{}_{}".format(stage_type, key2str(key))
                    dot.append('    subgraph "cluster_{}" {{'.format(name))
                    dot.append('      label="{}, sel={}";'.format(str(key), node.sel))

                    # Inputs
                    for drv_key, pin in node.inp.items():
                        if node.sel == pin:
                            assert drv_key in nodes, drv_key
                            net = nodes[drv_key].net
                        else:
                            net = None

                        name = "{}_{}_{}".format(stage_type, key2str(key), pin)
                        label = pin
                        color = node_colors[net]

                        dot.append(
                            '      "{}" [shape=ellipse label="{}" fillcolor="{}"];'.format(
                                name,
                                label,
                                color,
                            )
                        )

                    # Output
                    name = "{}_{}".format(stage_type, key2str(key))
                    label = "out"
                    color = node_colors[node.net]

                    dot.append(
                        '      "{}" [shape=ellipse label="{}" fillcolor="{}"];'.format(
                            name,
                            label,
                            color,
                        )
                    )

                    # Internal mux edges
                    for drv_key, pin in node.inp.items():
                        if node.sel == pin:
                            assert drv_key in nodes, drv_key
                            net = nodes[drv_key].net
                        else:
                            net = None

                        src_name = "{}_{}_{}".format(stage_type, key2str(key), pin)
                        dst_name = "{}_{}".format(stage_type, key2str(key))
                        color = edge_colors[net]

                        dot.append(
                            '      "{}" -> "{}" [color="{}"];'.format(
                                src_name,
                                dst_name,
                                color,
                            )
                        )

                    dot.append("    }")

                else:
                    assert False, node.type

            # Mux to mux connections
            for key, node in nodes.items():

                # Source node
                if node.type == self.NodeType.SOURCE:
                    pass

                # Sink node
                elif node.type == self.NodeType.SINK:
                    assert len(node.inp) == 1, node.inp
                    src_key = next(iter(node.inp.keys()))

                    dst_name = "{}_out_{}".format(stage_type, key2str(key))
                    if isinstance(src_key, str):
                        src_name = "{}_inp_{}".format(stage_type, key2str(src_key))
                    else:
                        src_name = "{}_{}".format(stage_type, key2str(src_key))

                    color = node_colors[node.net]

                    dot.append(
                        '    "{}" -> "{}" [color="{}"];'.format(
                            src_name,
                            dst_name,
                            color,
                        )
                    )

                # Mux node
                elif node.type == self.NodeType.MUX:
                    for drv_key, pin in node.inp.items():
                        if node.sel == pin:
                            assert drv_key in nodes, drv_key
                            net = nodes[drv_key].net
                        else:
                            net = None

                        dst_name = "{}_{}_{}".format(stage_type, key2str(key), pin)
                        if isinstance(drv_key, str):
                            src_name = "{}_inp_{}".format(stage_type, key2str(drv_key))
                        else:
                            src_name = "{}_{}".format(stage_type, key2str(drv_key))

                        color = edge_colors[net]

                        dot.append(
                            '    "{}" -> "{}" [color="{}"];'.format(
                                src_name,
                                dst_name,
                                color,
                            )
                        )

                else:
                    assert False, node.type

            # Stage footer
            dot.append("  }")

        # Add footer
        dot.append("}")
        return "\n".join(dot)


# =============================================================================


def main():

    # Parse arguments
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument("--techfile", type=str, required=True, help="Quicklogic 'TechFile' XML file")
    parser.add_argument("--fasm", type=str, default="default.fasm", help="Output FASM file name")
    parser.add_argument(
        "--device", type=str, choices=["eos-s3"], default="eos-s3", help="Device name to generate the FASM file for"
    )
    parser.add_argument(
        "--dump-dot", action="store_true", help="Dump Graphviz .dot files for each routed switchbox type"
    )
    parser.add_argument("--allow-routing-failures", action="store_true", help="Skip switchboxes that fail routing")

    args = parser.parse_args()

    # Read and parse the XML file
    xml_tree = ET.parse(args.techfile)
    xml_root = xml_tree.getroot()

    # Load data
    print("Loading data from the techfile...")
    data = import_data(xml_root)
    switchbox_types = data["switchbox_types"]
    switchbox_grid = data["switchbox_grid"]
    tile_types = data["tile_types"]
    tile_grid = data["tile_grid"]

    # Route switchboxes
    print("Making switchbox routes...")

    fasm = []
    fully_routed = 0
    partially_routed = 0

    def input_rank(pin):
        """
        Returns a rank of a switchbox input. Pins with the lowest rank should
        be expanded first.
        """
        if pin.name == "GND":
            return 0
        elif pin.name == "VCC":
            return 1
        elif pin.type not in [SwitchboxPinType.HOP, SwitchboxPinType.GCLK]:
            return 2
        elif pin.type == SwitchboxPinType.HOP:
            return 3
        elif pin.type == SwitchboxPinType.GCLK:
            return 4

        return 99

    # Scan for duplicates
    for switchbox in switchbox_types.values():
        for pin in switchbox.pins:
            pinmap = {}
            for pin_loc in pin.locs:
                key = (switchbox.type, pin_loc.stage_id, pin_loc.switch_id, pin_loc.mux_id)
                if key not in pinmap:
                    pinmap[key] = pin_loc.pin_id
                else:
                    if key in duplicate:
                        duplicate[key].append(pin_loc.pin_id)
                    else:
                        duplicate[key] = [pin_loc.pin_id]

    # Process each switchbox type
    for switchbox in switchbox_types.values():
        print("", switchbox.type)

        # Identify all locations of the switchbox
        locs = [loc for loc, type in switchbox_grid.items() if type == switchbox.type]

        # Initialize the builder
        builder = SwitchboxConfigBuilder(switchbox)

        # Sort the inputs according to their ranks.
        inputs = sorted(switchbox.inputs.values(), key=input_rank)

        # Propagate them
        for stage in ["STREET", "HIGHWAY"]:
            for pin in inputs:
                if pin.name in builder.stage_inputs(stage):
                    builder.propagate_input(stage, pin.name)

        # Check if all nodes are configured
        routing_failed = not builder.check_nodes()

        # Dump dot
        if args.dump_dot:
            dot = builder.dump_dot()
            fname = "defconfig_{}.dot".format(switchbox.type)
            with open(fname, "w") as fp:
                fp.write(dot)

        # Routing failed
        if routing_failed:
            if not args.allow_routing_failures:
                exit(-1)

        # Stats
        if routing_failed:
            partially_routed += len(locs)
        else:
            fully_routed += len(locs)

        # Emit FASM features for each of them
        for loc in locs:
            fasm.extend(builder.fasm_features(loc))

    print(" Total switchboxes: {}".format(len(switchbox_grid)))
    print(" Fully routed     : {}".format(fully_routed))
    print(" Partially routed : {}".format(partially_routed))

    # Power on all LOGIC cells
    for loc, tile in tile_grid.items():

        # Get the tile type object
        tile_type = tile_types[tile.type]

        # If this tile has a LOGIC cell then emit the FASM feature that
        # enables its power
        if "LOGIC" in tile_type.cells:
            feature = "X{}Y{}.LOGIC.LOGIC.Ipwr_gates.J_pwr_st".format(loc.x, loc.y)
            fasm.append(feature)

    # Write FASM
    print("Writing FASM file...")
    with open(args.fasm, "w") as fp:
        fp.write("\n".join(fasm))


# =============================================================================

if __name__ == "__main__":
    main()
