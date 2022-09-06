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
A set of utility functions responsible for loading a packed netlist into a
complex block routing graph and creating a packed netlist from a graph with
routing information.
"""

from f4pga.aux.utils.quicklogic.repacker.block_path import PathNode

import f4pga.aux.utils.quicklogic.repacker.packed_netlist as packed_netlist

# =============================================================================


def get_block_by_path(block, path):
    """
    Returns a block given its hierarchical path. The path must be a list of
    PathNode objects.
    """

    if len(path) == 0:
        return block

    # Find instance
    instance = "{}[{}]".format(path[0].name, path[0].index)
    if instance in block.blocks:
        block = block.blocks[instance]

        # Check operating mode
        if path[0].mode is not None:
            if block.mode != path[0].mode:
                return None

        # Recurse
        return get_block_by_path(block, path[1:])

    return None


# =============================================================================


def load_clb_nets_into_pb_graph(clb_block, clb_graph):
    """
    Loads packed netlist of the given CLB block into its routing graph
    """

    # Annotate nodes with nets
    for node in clb_graph.nodes.values():
        # Disassemble node path parts
        parts = node.path.split(".")
        parts = [PathNode.from_string(p) for p in parts]

        # Check if the node belongs to this CLB
        block_inst = "{}[{}]".format(parts[0].name, parts[0].index)
        assert block_inst == clb_block.instance, (block_inst, clb_block.instance)

        # Find the block referred to by the node
        block = get_block_by_path(clb_block, parts[1:-1])
        if block is None:
            continue

        # Find a corresponding port in the block
        node_port = parts[-1]
        if node_port.name not in block.ports:
            continue
        block_port = block.ports[node_port.name]

        # Find a net for the port pin and assign it
        net = block.find_net_for_port(block_port.name, node_port.index)
        node.net = net


# =============================================================================


def build_packed_netlist_from_pb_graph(clb_graph):
    """
    This function builds a packed netlist fragment given an annotated (with
    nets) CLB graph. The created netlist fragment will be missing information:

      - Atom block names
      - Atom block attributes and parameters

    The missing information has to be supplied externally as it is not stored
    within a graph.

    The first step is to create the block hierarchy (without any ports yet).
    This is done by scanning the graph and creating blocks for nodes that
    belong to nets. Only those nodes are used here.

    The second stage is open block insertion. Whenever a non-leaf is in use
    it should have all of its children present. Unused ones should be makred
    as "open".

    The third stage is adding ports to the blocks and connectivity information.
    To gather all necessary information all the nodes of the graph are needed.

    The final step is leaf block name assignment. Leaf blocks get their names
    based on nets they drive. A special case is a block representing an output
    that doesn't drive anything. Such blocks get names based on their inputs
    but prefixed with "out:".
    """

    # Build node connectivity. These two maps holds upstream and downstream
    # node sets for a given node. They consider active nodes only.
    nodes_up = {}

    for edge in clb_graph.edges:
        # Check if the edge is active
        if clb_graph.edge_net(edge) is None:
            continue

        # Up map
        if edge.dst_id not in nodes_up:
            nodes_up[edge.dst_id] = set()
        nodes_up[edge.dst_id].add((edge.src_id, edge.ic))

    # Create the block hierarchy for nodes that have nets assigned.
    clb_block = None
    for node in clb_graph.nodes.values():
        # No net
        if node.net is None:
            continue

        # Disassemble node path parts
        parts = node.path.split(".")
        parts = [PathNode.from_string(p) for p in parts]

        # Create the root CLB
        instance = "{}[{}]".format(parts[0].name, parts[0].index)
        if clb_block is None:
            clb_block = packed_netlist.Block(name="clb", instance=instance)  # FIXME:
        else:
            assert clb_block.instance == instance

        # Follow the path, create blocks
        parent = clb_block
        for prev_part, curr_part in zip(parts[0:-2], parts[1:-1]):
            instance = "{}[{}]".format(curr_part.name, curr_part.index)
            parent_mode = prev_part.mode

            # Get an existing block
            if instance in parent.blocks:
                block = parent.blocks[instance]

            # Create a new block
            else:
                block = packed_netlist.Block(name="", instance=instance, parent=parent)
                block.name = "block@{:08X}".format(id(block))
                parent.blocks[instance] = block

            # Set / verify operating mode of the parent
            if parent_mode is not None:
                assert parent.mode in [None, parent_mode], (parent.mode, parent_mode)
                parent.mode = parent_mode

            # Next level
            parent = block

    # Check if the CLB got created
    assert clb_block is not None

    # Add open blocks.
    for node in clb_graph.nodes.values():
        # Consider only nodes without nets
        if node.net:
            continue

        # Disassemble node path parts
        parts = node.path.split(".")
        parts = [PathNode.from_string(p) for p in parts]

        if len(parts) < 3:
            continue

        # Find parent block
        parent = get_block_by_path(clb_block, parts[1:-2])
        if not parent:
            continue

        # Operating mode of the parent must match
        if parent.mode != parts[-3].mode:
            continue

        # Check if the parent contains an open block correesponding to this
        # node.
        curr_part = parts[-2]
        instance = "{}[{}]".format(curr_part.name, curr_part.index)

        if instance in parent.blocks:
            continue

        # Create an open block
        block = packed_netlist.Block(name="open", instance=instance, parent=parent)
        parent.blocks[block.instance] = block

    # Add block ports and their connections
    for node in clb_graph.nodes.values():
        # Disassemble node path parts
        parts = node.path.split(".")
        parts = [PathNode.from_string(p) for p in parts]

        # Find the block. If not found it meas that it is not active and
        # shouldn't be present in the netlist
        block = get_block_by_path(clb_block, parts[1:-1])
        if block is None:
            continue

        # The block is open, skip
        if block.is_open:
            continue

        # Get the port, add it if not present
        port_name = parts[-1].name
        port_type = node.port_type.name.lower()
        if port_name not in block.ports:
            # The relevant information will be updated as more nodes gets
            # discovered.
            port = packed_netlist.Port(name=port_name, type=port_type)
            block.ports[port_name] = port

        else:
            port = block.ports[port_name]
            assert port.type == port_type, (port.type, port_type)

        # Extend the port width if necessary
        bit_index = parts[-1].index
        port.width = max(port.width, bit_index + 1)

        # The port is not active, nothing more to be done here
        if node.net is None:
            continue

        # Identify driver of the port
        driver_node = None
        driver_conn = None
        if node.id in nodes_up:
            assert len(nodes_up[node.id]) <= 1, node.path
            driver_node, driver_conn = next(iter(nodes_up[node.id]))

        # Got a driver, this is an intermediate port
        if driver_node is not None:
            # Get the driver pb_type and port
            driver_path = clb_graph.nodes[driver_node].path.split(".")
            driver_path = [PathNode.from_string(driver_path[i]) for i in [-2, -1]]

            # When a connection refers to the immediate parent do not include
            # block index suffix
            driver_instance = driver_path[0].name
            if block.parent is None or block.parent.type != driver_path[0].name:
                driver_instance += "[{}]".format(driver_path[0].index)

            # Add the connection
            port.connections[bit_index] = packed_netlist.Connection(
                driver_instance, driver_path[1].name, driver_path[1].index, driver_conn
            )

        # No driver, this is a source pin
        else:
            port.connections[bit_index] = node.net

    # Assign names to leaf blocks
    def leaf_walk(block):
        # A leaf
        if block.is_leaf and not block.is_open:
            # Identify all output pins that drive nets
            nets = []
            for port in block.ports.values():
                if port.type == "output":
                    for net in port.connections.values():
                        if isinstance(net, str):
                            nets.append(net)

            # No nets driven, this is an output pad
            if not nets:
                assert "outpad" in block.ports

                port = block.ports["outpad"]
                assert port.type == "input", port
                assert port.width == 1, port

                net = block.find_net_for_port("outpad", 0)
                nets = ["out:" + net]

            # Build block name and assign it
            if nets:
                block.name = "_".join(nets)

        # Recurse
        for child in block.blocks.values():
            leaf_walk(child)

    leaf_walk(clb_block)

    # Return the top-level CLB block
    return clb_block
