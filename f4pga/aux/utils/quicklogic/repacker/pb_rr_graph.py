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
A set of utils for VTR pb_type rr graphs
"""

import itertools
import colorsys

from enum import Enum

from f4pga.aux.utils.quicklogic.repacker.block_path import PathNode

from f4pga.aux.utils.quicklogic.repacker.pb_type import PortType

from f4pga.aux.utils.quicklogic.repacker.arch_xml_utils import is_leaf_pbtype
from f4pga.aux.utils.quicklogic.repacker.arch_xml_utils import get_parent_pb
from f4pga.aux.utils.quicklogic.repacker.arch_xml_utils import yield_pb_children
from f4pga.aux.utils.quicklogic.repacker.arch_xml_utils import yield_pins

# =============================================================================


class NodeType(Enum):
    """
    Type of a pb graph node
    """

    PORT = 0
    SOURCE = 1
    SINK = 2


class Node:
    """
    This class represents a node in pb graph. Nodes are associated with port
    pins.
    """

    def __init__(self, id, type, port_type, path, net=None):
        self.id = id
        self.type = type
        self.port_type = port_type
        self.path = path
        self.net = net

    def __str__(self):
        return "id:{:3d}, type:{}, port_type:{}, path:{}, net:{}".format(
            self.id, self.type, self.port_type, self.path, self.net
        )


class Edge:
    """
    This class represents an edge in pb_graph. Edges are associated with
    interconnect connections.
    """

    def __init__(self, src_id, dst_id, ic):
        self.src_id = src_id
        self.dst_id = dst_id
        self.ic = ic

    def __str__(self):
        return "src_id:{}, dst_id:{}, ic:{}".format(self.src_id, self.dst_id, self.ic)


# =============================================================================


class Graph:
    """
    Representation of a complex block routing graph.

    This class stores only nodes and edges instead of a hierarchical tree of
    objects representing blocks (pb_types). Graph nodes are associated with
    pb_type ports. Each node has a path that uniquely identifies which port
    it represents.
    """

    def __init__(self):
        # Nodes by id
        self.nodes = {}
        # Edges (assorted)
        self.edges = []

        # Id of the next node to be added
        self.next_node_id = 0

    def add_node(self, type, port_type, path, net=None):
        """
        Adds a new node. Automatically assings its id
        """
        node = Node(id=self.next_node_id, type=type, port_type=port_type, path=path, net=net)

        self.nodes[node.id] = node
        self.next_node_id += 1

        return node

    def add_edge(self, src_id, dst_id, ic):
        """
        Adds a new edge. Checks if the given node ids are valid.
        """
        assert src_id in self.nodes, src_id
        assert dst_id in self.nodes, dst_id

        edge = Edge(src_id=src_id, dst_id=dst_id, ic=ic)

        self.edges.append(edge)

        return edge

    def clear_nets(self):
        """
        Removes all net annotations
        """
        for node in self.nodes.values():
            node.net = None

    def edge_net(self, edge):
        """
        Returns net associated with the given edge

        Edges do not have explicit net annotations. It is assumed that when
        an edge binds two nodes that belong to the same net, that edge belongs
        to that net as well.
        """
        src_node = self.nodes[edge.src_id]
        dst_node = self.nodes[edge.dst_id]

        if src_node.net is None:
            return None
        if dst_node.net is None:
            return None

        if src_node.net != dst_node.net:
            return None

        return src_node.net

    @staticmethod
    def from_etree(xml_clb, clb_instance=None):
        """
        Builds a routing graph for the given complex block from VPR
        architecture XML description.
        """
        assert xml_clb.tag == "pb_type"

        # Create the graph
        graph = Graph()

        # Handler for "lut" pb_types. It creates an additional level of
        # hierarchy to match the representation in packed netlist.
        def process_lut(xml_pbtype, up_node_map, path):
            # The parent is actually a leaf so it does not have any modes
            # However, the mode name must equal to the pb_type name.
            curr_path = path + "[{}].lut[0]".format(xml_pbtype.attrib["name"])

            # Copy nodes from the parent and connect them 1-to-1
            for parent_node in up_node_map.values():
                parent_port = parent_node.path.rsplit(".", maxsplit=1)[-1]

                # Add node
                node = graph.add_node(parent_node.type, parent_node.port_type, ".".join([curr_path, parent_port]))

                # Add edge
                ic = "direct:{}".format(xml_pbtype.attrib["name"])
                if parent_node.port_type in [PortType.INPUT, PortType.CLOCK]:
                    graph.add_edge(parent_node.id, node.id, ic)
                elif parent_node.port_type == PortType.OUTPUT:
                    graph.add_edge(node.id, parent_node.id, ic)
                else:
                    assert False, parent_node

            # Change parent port nodes to PORT
            for parent_node in up_node_map.values():
                parent_node.type = NodeType.PORT

        # Recursive build function
        def process_pbtype(xml_pbtype, up_node_map, path=""):
            """
            This function adds nodes for all child pb_type ports and edges
            connecting them with the parent pb_type ports. The process is
            repeated for each mode.

            Before the first level of recursion nodes of the top-level pb_type
            need to be already built.
            """

            # Identify all modes. If there is none then add the default
            # implicit one.
            xml_modes = {x.attrib["name"]: x for x in xml_pbtype.findall("mode")}
            if not xml_modes:
                xml_modes = {"default": xml_pbtype}

            # Process each mode
            for mode, xml_mode in xml_modes.items():
                # Append mode name to the current path
                curr_path = path + "[{}]".format(mode)

                # Enumerate childern, build their paths
                children = []
                for xml_child, index in yield_pb_children(xml_mode):
                    child_path = ".".join([curr_path, "{}[{}]".format(xml_child.attrib["name"], index)])

                    children.append(
                        (
                            xml_child,
                            child_path,
                        )
                    )

                # Build child pb_type nodes
                dn_node_map = {}
                for xml_child, child_path in children:
                    nodes = graph._build_nodes(xml_child, child_path)
                    dn_node_map.update(nodes)

                    # Special case, a "lut" class leaf pb_type
                    cls = xml_child.get("class", None)
                    if cls == "lut":
                        process_lut(xml_child, nodes, child_path)

                # Build interconnect edges
                xml_ic = xml_mode.find("interconnect")
                assert xml_ic is not None

                graph._build_edges(xml_ic, curr_path, up_node_map, dn_node_map)

                # Recurse
                for xml_child, child_path in children:
                    if not is_leaf_pbtype(xml_child):
                        process_pbtype(xml_child, dn_node_map, child_path)

        # Set the top-level CLB path
        if clb_instance is None:
            path = xml_clb.attrib["name"] + "[0]"
        else:
            path = clb_instance

        # Build top-level sources and sinks
        up_node_map = graph._build_nodes(xml_clb, path)

        # Begin recustion
        process_pbtype(xml_clb, up_node_map, path)

        return graph

    def _build_nodes(self, xml_pbtype, prefix):
        """
        Adds nodes for each pin of the given pb_type. Returns a map of pin
        names to node ids
        """
        node_map = {}

        # Sink/source node type map
        leaf_node_types = {
            "input": NodeType.SINK,
            "clock": NodeType.SINK,
            "output": NodeType.SOURCE,
        }

        top_node_types = {
            "input": NodeType.SOURCE,
            "clock": NodeType.SOURCE,
            "output": NodeType.SINK,
        }

        # Determine where the pb_type is in the hierarchy
        is_leaf = is_leaf_pbtype(xml_pbtype)
        is_top = get_parent_pb(xml_pbtype) is None
        assert not (is_top and is_leaf), (xml_pbtype.tag, xml_pbtype.attrib)

        # Add nodes
        for xml_port in xml_pbtype:
            if xml_port.tag in ["input", "output", "clock"]:
                width = int(xml_port.attrib["num_pins"])

                # Determine node type
                if is_top:
                    node_type = top_node_types[xml_port.tag]
                elif is_leaf:
                    node_type = leaf_node_types[xml_port.tag]
                else:
                    node_type = NodeType.PORT

                # Determine node port direction
                port_type = PortType.from_string(xml_port.tag)

                # Add a node for each pin
                for i in range(width):
                    name = "{}[{}]".format(xml_port.attrib["name"], i)
                    path = ".".join([prefix, name])
                    node = self.add_node(node_type, port_type, path)

                    node_map[path] = node

        return node_map

    def _build_edges(self, xml_ic, path, up_node_map, dn_node_map):
        """
        Builds edges for the given interconnect. Uses node maps to bind
        port pin names with node ids.
        """

        # Join node maps
        node_map = {**up_node_map, **dn_node_map}

        # Get parent pb_type and its name
        xml_pbtype = get_parent_pb(xml_ic)
        parent_name = xml_pbtype.attrib["name"]

        # Split the path
        path_parts = path.split(".")

        # A helper function
        def get_node_path(pin):
            # Split parts
            parts = pin.split(".")
            assert len(parts) == 2, pin

            # Parse the pb_type referred by the pin
            pin_pbtype = PathNode.from_string(parts[0])

            # This pin refers to the parent
            if pin_pbtype.name == parent_name:
                ref_pbtype = PathNode.from_string(path_parts[-1])

                # Fixup pb_type reference name
                part = "{}[{}]".format(
                    pin_pbtype.name,
                    ref_pbtype.index,
                )
                parts = path_parts[:-1] + [part] + parts[1:]

            else:
                parts = path_parts + parts

            # Assemble the full path
            node_path = ".".join(parts)
            return node_path

        # Process interconnects
        for xml_conn in xml_ic:
            # Direct
            if xml_conn.tag == "direct":
                inps = list(yield_pins(xml_ic, xml_conn.attrib["input"], False))
                outs = list(yield_pins(xml_ic, xml_conn.attrib["output"], False))

                assert len(inps) == len(outs), (xml_conn.tag, xml_conn.attrib, len(inps), len(outs))

                # Add edges
                for inp, out in zip(inps, outs):
                    inp = get_node_path(inp)
                    out = get_node_path(out)

                    self.add_edge(src_id=node_map[inp].id, dst_id=node_map[out].id, ic=xml_conn.attrib["name"])

            # Mux
            elif xml_conn.tag == "mux":
                inp_ports = xml_conn.attrib["input"].split()

                # Get output pins, should be only one
                out_pins = list(yield_pins(xml_ic, xml_conn.attrib["output"], False))
                assert len(out_pins) == 1, xml_ic.attrib

                # Build edges for each input port
                for inp_port in inp_ports:
                    # Get input pins, should be only one
                    inp_pins = list(yield_pins(xml_ic, inp_port, False))
                    assert len(inp_pins) == 1, xml_conn.attrib

                    # Add edge
                    inp = get_node_path(inp_pins[0])
                    out = get_node_path(out_pins[0])

                    self.add_edge(src_id=node_map[inp].id, dst_id=node_map[out].id, ic=xml_conn.attrib["name"])

            # Complete
            elif xml_conn.tag == "complete":
                inp_ports = xml_conn.attrib["input"].split()
                out_ports = xml_conn.attrib["output"].split()

                # Build lists of all input and all output pins
                inp_pins = []
                for inp_port in inp_ports:
                    inp_pins.extend(list(yield_pins(xml_ic, inp_port, False)))

                out_pins = []
                for out_port in out_ports:
                    out_pins.extend(list(yield_pins(xml_ic, out_port, False)))

                # Add edges
                for inp_pin, out_pin in itertools.product(inp_pins, out_pins):
                    inp = get_node_path(inp_pin)
                    out = get_node_path(out_pin)

                    self.add_edge(src_id=node_map[inp].id, dst_id=node_map[out].id, ic=xml_conn.attrib["name"])

    def dump_dot(self, color_by="type", nets_only=False, highlight_nodes=None):
        """
        Returns a string with the graph in DOT format suitable for the
        Graphviz.

        Nodes can be colored by "type" or "net". When nets_only is True then
        only nodes and edges that belong to a net are dumped.
        """
        dot = []

        # Build net color map
        if color_by == "net":
            nets = set([node.net for node in self.nodes.values()]) - set([None])
            nets = sorted(list(nets))

            net_colors = {}
            for i, net in enumerate(nets):
                h = i / len(nets)
                l = 0.50  # noqa: E741
                s = 1.0

                r, g, b = colorsys.hls_to_rgb(h, l, s)
                color = "#{:02X}{:02X}{:02X}".format(
                    int(r * 255.0),
                    int(g * 255.0),
                    int(b * 255.0),
                )

                net_colors[net] = color

        # Node color
        def node_color(node, highlight=False):
            if highlight_nodes:
                if highlight:
                    return "#FF2020"
                elif node.net:
                    return "#808080"
                else:
                    return "#C0C0C0"

            # By type
            if color_by == "type":
                if node.type == NodeType.SOURCE:
                    return "#C08080"
                elif node.type == NodeType.SINK:
                    return "#8080C0"
                else:
                    return "#C0C0C0"

            # By net
            elif color_by == "net":
                if node.net is None:
                    return "#C0C0C0"
                else:
                    return net_colors[node.net]

            # Default
            else:
                return "#C0C0C0"

        # Edge color
        def edge_color(edge):
            if color_by == "net":
                net = self.edge_net(edge)
                if net:
                    return net_colors[net]
                else:
                    return "#C0C0C0"

            # Default
            else:
                return "#C0C0C0"

        # Add header
        dot.append("digraph g {")
        dot.append(" rankdir=LR;")
        dot.append(" ratio=0.5;")
        dot.append(" splines=false;")
        dot.append(" node [style=filled];")

        # Build nodes
        nodes = {}
        for node in self.nodes.values():
            if nets_only and node.net is None:
                continue

            highlight = highlight_nodes is not None and node.id in highlight_nodes  # noqa: E127

            parts = node.path.split(".")
            label = "{}: {}".format(node.id, ".".join(parts[-2:]))
            color = node_color(node, highlight)
            rank = 0

            if node.net:
                xlabel = node.net
            else:
                xlabel = ""

            if node.type == NodeType.SOURCE:
                shape = "diamond"
            elif node.type == NodeType.SINK:
                shape = "octagon"
            else:
                shape = "ellipse"

            if rank not in nodes:
                nodes[rank] = []

            nodes[rank].append({"id": node.id, "label": label, "xlabel": xlabel, "color": color, "shape": shape})

        # Add nodes
        for rank, nodes in nodes.items():
            dot.append(" {")

            for node in nodes:
                dot.append(
                    '  node_{} [label="{}",xlabel="{}",fillcolor="{}",shape={}];'.format(
                        node["id"],
                        node["label"],
                        node["xlabel"],
                        node["color"],
                        node["shape"],
                    )
                )

            dot.append(" }")

        # Add edges
        for edge in self.edges:
            if nets_only:
                if not self.edge_net(edge):
                    continue

            label = edge.ic
            color = edge_color(edge)

            dot.append(' node_{} -> node_{} [label="{}",color="{}"];'.format(edge.src_id, edge.dst_id, label, color))

        # Footer
        dot.append("}")
        return "\n".join(dot)
