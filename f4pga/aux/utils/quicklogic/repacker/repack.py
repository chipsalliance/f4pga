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
A SymbiFlow implementation of OpenFPGA re-packer.

The repacker utility is responsible for converting a VPR packed netlist
expressed using "operating" modes of pb_types so that it is expressed using
cells from physical modes that represent the underlying hardware. For more
details please refer to the documentation of the OpenFPGA project:
https://openfpga.readthedocs.io/en/master/manual/openfpga_shell/openfpga_commands/fpga_bitstream_commands/#repack

Please refer to the README.md file for more details on the tool operation and
implementation.
"""

import logging
import argparse
import sys
import os
import shlex
import hashlib
import time
from collections import namedtuple

import json
import lxml.etree as ET

from f4pga.aux.utils.quicklogic.repacker.block_path import PathNode

from f4pga.aux.utils.quicklogic.repacker.eblif_netlist import Eblif, Cell
import f4pga.aux.utils.quicklogic.repacker.netlist_cleaning as netlist_cleaning

import f4pga.aux.utils.quicklogic.repacker.packed_netlist as pn
from f4pga.aux.utils.quicklogic.repacker.packed_netlist import PackedNetlist
from f4pga.aux.utils.quicklogic.repacker.pb_rr_graph import Graph, NodeType
from f4pga.aux.utils.quicklogic.repacker.pb_rr_graph_router import Router

from f4pga.aux.utils.quicklogic.repacker.pb_rr_graph_netlist import load_clb_nets_into_pb_graph
from f4pga.aux.utils.quicklogic.repacker.pb_rr_graph_netlist import build_packed_netlist_from_pb_graph

from f4pga.aux.utils.quicklogic.repacker.pb_type import PbType, Model, PortType
from f4pga.aux.utils.pcf import parse_simple_pcf


class RepackingRule:
    """
    A structure for representing repacking rule.
    """

    def __init__(self, src, dst, index_map, port_map, mode_bits=None):
        self.src = src
        self.dst = dst
        self.index_map = index_map
        self.port_map = port_map
        self.mode_bits = mode_bits

    def remap_pb_type_index(self, index):
        """
        Remaps the given source pb_type index to the destination pb_type index
        """
        return index * self.index_map[0] + self.index_map[1]


class RepackingConstraint:
    """
    Represents a constraint imposed on a given net name
    """

    def __init__(self, net, block_type, port_spec):
        port = PathNode.from_string(port_spec)

        self.net = net
        self.block_type = block_type
        self.port = port.name
        self.pin = port.index


# =============================================================================


def fixup_route_throu_luts(clb_block, new_net_ids):
    """
    This function identifies route-throu LUTs in the packed netlist and
    replaces them with explicit LUT-1 blocks.

    The function returns a list of net pairs denoting input and output nets of
    each inserted buffer LUT-1 block.
    """

    blocks = []

    def walk(block):
        """
        Recursively walks over packed netlist and collects route-throu LUTs
        """

        # This is a leaf block
        if block.is_leaf:
            if block.is_route_throu:
                blocks.append(block)

        # Recurse for all children
        else:
            for child in block.blocks.values():
                walk(child)

    # Collect route-throu LUTs
    walk(clb_block)

    if not blocks:
        return []

    # Process blocks
    net_pairs = []

    for block in blocks:
        logging.debug("   " + str(block))

        # Idnetify input and output to be routed together. There should be
        # only one of each.
        Port = namedtuple("Port", "port pin")

        blk_inp = None
        blk_out = None

        for port in block.ports.values():
            for pin, conn in port.connections.items():
                if port.type in ["input", "clock"]:
                    if blk_inp is None:
                        blk_inp = Port(port, pin)
                    else:
                        assert False

                elif port.type == "output":
                    if blk_out is None:
                        blk_out = Port(port, pin)
                    else:
                        assert False

                else:
                    assert False, port.type

        # Check if we have both input and output
        assert blk_inp and blk_out

        # Identify the net
        net_inp = block.find_net_for_port(blk_inp.port.name, blk_inp.pin)
        assert net_inp is not None

        # Create a new net to be driven by the route-throu LUT
        if net_inp not in new_net_ids:
            new_net_ids[net_inp] = 0

        net_out = net_inp + "$buf{}".format(new_net_ids[net_inp])
        new_net_ids[net_inp] += 1

        net_pairs.append((net_inp, net_out))

        # Insert the route-throu LUT as an explicit block
        lut_block = pn.Block(name=net_out, instance="lut[0]", mode="default", parent=block)
        block.blocks[lut_block.instance] = lut_block

        # Add LUT ports with connections
        lut_block.ports[blk_inp.port.name] = pn.Port(
            name=blk_inp.port.name,
            type=blk_inp.port.type,
            width=blk_inp.port.width,
            connections={
                blk_inp.pin: pn.Connection(
                    driver=block.type, port=blk_inp.port.name, pin=blk_inp.pin, interconnect="direct"
                )
            },
        )

        lut_block.ports[blk_out.port.name] = pn.Port(
            name=blk_out.port.name, type=blk_out.port.type, width=blk_out.port.width, connections={blk_out.pin: net_out}
        )

        # Set input port rotation. This will allow to have a simple LUT-1
        # buffer in the circuit netlist.
        lut_block.ports[blk_inp.port.name].rotation_map = {blk_inp.pin: 0}

        # Update the block output port to reference the LUT
        blk_out.port.connections = {
            blk_out.pin: pn.Connection(
                driver=lut_block.instance, port=blk_out.port.name, pin=blk_out.pin, interconnect="direct"
            )
        }

        # Update the block mode and name
        block.name = lut_block.name
        block.mode = block.type

    return net_pairs


def insert_buffers(nets, eblif, clb_block):
    """
    For the given list of net pairs the function inserts buffer cells to
    the circuit netlist.
    """

    def walk(block, net, collected_blocks):
        # This is a leaf block
        if block.is_leaf:
            # Check every input port connection, identify driving nets. Store
            # the block if at least one input is driven by the given net.
            for port in block.ports.values():
                if port.type in ["input", "clock"]:
                    for pin in port.connections:
                        pin_net = block.find_net_for_port(port.name, pin)

                        if pin_net == net:
                            collected_blocks.append(block)
                            return

        # Recurse for all children
        else:
            for child in block.blocks.values():
                walk(child, net, collected_blocks)

    # Insert buffers for each new net
    for net_inp, net_out in nets:
        # Insert the buffer cell. Here it is a LUT-1 configured as buffer.
        cell = Cell("$lut")
        cell.name = net_out
        cell.ports["lut_in[0]"] = net_inp
        cell.ports["lut_out"] = net_out
        cell.init = [0, 1]
        assert cell.name not in eblif.cells, cell
        eblif.cells[cell.name] = cell

        # Collects blocks driven by the output net
        blocks = []
        walk(clb_block, net_out, blocks)

        # Remap block cell connections
        for block in blocks:
            # Find cell for the block
            cell = eblif.find_cell(block.name)
            assert cell is not None, block

            # Find a port referencing the input net. Change it to the output
            # net
            for port in cell.ports:
                if cell.ports[port] == net_inp:
                    cell.ports[port] = net_out


# =============================================================================


def identify_blocks_to_repack(clb_block, repacking_rules):
    """
    Identifies all blocks in the packed netlist that require re-packing
    """

    def walk(block, path):
        """
        Recursively walk the path and yield matching blocks from the packed
        netlist
        """

        # No more path nodes to follow
        if not path:
            return

        # The block is "open"
        if block.is_open:
            return

        # Check if the current block is a LUT
        is_lut = len(block.blocks) == 1 and "lut[0]" in block.blocks and block.blocks["lut[0]"].is_leaf  # noqa: E127

        # Check if the block match the path node. Check type and mode
        block_node = PathNode.from_string(block.instance)
        block_node.mode = block.mode

        path_node = path[0]

        if block_node.name != path_node.name:
            return

        if not block.is_leaf:
            mode = "default" if is_lut else block_node.mode
            if path_node.mode != mode:
                return

        # If index is explicitly given check it as well
        if path_node.index is not None and path_node.index != block_node.index:
            return

        # This is a leaf block, add it
        if block.is_leaf and not block.is_open:
            assert len(path) == 1, (path, block)
            yield block

        # This is not a leaf block
        else:
            # Add the implicit LUT hierarchy to the path
            if is_lut:
                path.append(PathNode.from_string("lut[0]"))

            # Recurse
            for child in block.blocks.values():
                yield from walk(child, path[1:])

    # For each rule
    blocks_to_repack = []
    for rule in repacking_rules:
        logging.debug("   checking rule path '{}'...".format(rule.src))

        # Parse the path
        path = [PathNode.from_string(p) for p in rule.src.split(".")]

        # Substitute non-explicit modes with "default" to match the packed
        # netlist
        for part in path:
            if part.mode is None:
                part.mode = "default"

        # Walk
        for block in walk(clb_block, path):
            logging.debug("    " + str(block))

            # Append to list
            blocks_to_repack.append((block, rule))

    return blocks_to_repack


def fix_block_path(block_path, arch_path, change_mode=True):
    """
    Given a hierarchical path without explicit modes and indices adds them to
    those nodes that match with the block path.

    The last node with matching name and index will have its mode changed to
    match the given path if change_mode is True.
    """

    # Get the full path (with indices and modes) to the block
    block_path = block_path.split(".")
    arch_path = arch_path.split(".")

    length = min(len(arch_path), len(block_path))

    # Process the path
    for i in range(length):
        # Parse both path nodes
        arch_node = PathNode.from_string(arch_path[i])
        block_node = PathNode.from_string(block_path[i])

        # Name doesn't match
        if arch_node.name != block_node.name:
            break
        # Index doesn't match
        if arch_node.index is not None and arch_node.index != block_node.index:
            break

        # Optionally change mode as in the architecture path
        if change_mode:
            mode = arch_node.mode if arch_node.mode else "default"
        else:
            mode = block_node.mode

        # Fix the node
        arch_path[i] = str(PathNode(block_node.name, block_node.index, mode))

        # If the mode does not match then break
        if arch_node.mode is not None and block_node.mode != "default":
            if arch_node.mode != block_node.mode:
                break

    # Join the modified path back
    return ".".join(arch_path)


def identify_repack_target_candidates(clb_pbtype, path):
    """
    Given a hierarchical path and a root CLB identifies all leaf pb_types that
    match that path and yields them.

    The path may be "fixed" (having explicit modes and pb indices) up to some
    depth. When a path node refers to a concrete pb_type then the algorightm
    follows exactly that path.

    For non-fixed path nodes the algorithm explores all possiblities and yields
    them.
    """

    def walk(arch_path, pbtype, pbtype_index, curr_path=None):
        # Parse the path node
        if arch_path:
            path_node = PathNode.from_string(arch_path[0])
            arch_path = arch_path[1:]

        # No more path nodes, consider all wildcards
        else:
            path_node = PathNode(None, None, None)

        # Check if the name matches
        pbtype_name = pbtype.name
        if path_node.name is not None and path_node.name != pbtype_name:
            return

        # Check if the index matches
        if path_node.index is not None and path_node.index != pbtype_index:
            return

        # Initialize the current path if not given
        if curr_path is None:
            curr_path = []

        # This is a leaf pb_type. Yield path to it
        if pbtype.is_leaf:
            part = "{}[{}]".format(pbtype_name, pbtype_index)
            yield (".".join(curr_path + [part]), pbtype)

        # Recurse
        for mode_name, mode in pbtype.modes.items():
            # Check mode if given
            if path_node.mode is not None and path_node.mode != mode_name:
                continue

            # Recurse for children
            for child, i in mode.yield_children():
                # Recurse
                part = "{}[{}][{}]".format(pbtype_name, pbtype_index, mode_name)
                yield from walk(arch_path, child, i, curr_path + [part])

    # Split the path
    path = path.split(".")

    # Get CLB index from the path
    part = PathNode.from_string(path[0])
    clb_index = part.index

    # Begin walk
    candidates = list(walk(path, clb_pbtype, clb_index))
    return candidates


# =============================================================================


def annotate_net_endpoints(clb_graph, block, block_path=None, constraints=None, port_map=None, def_map=None):
    """
    This function annotates SOURCE and SINK nodes of the block pointed by
    block_path with nets of their corresponding ports but from the other given
    block.

    This essentially does the block re-packing at the packed netlist level.
    """

    # Invert the port map (is src->dst, we need dst->src)
    if port_map is not None:
        inv_port_map = {v: k for k, v in port_map.items()}

    # Get block path
    if block_path is None:
        block_path = block.get_path()

    # Remove mode from the last node of the path
    # Get the destination block type
    block_path = [PathNode.from_string(p) for p in block_path.split(".")]
    block_type = block_path[0].name
    block_path[-1].mode = None
    block_path = ".".join([str(p) for p in block_path])

    # Identify and annotate SOURCE and SINK nodes
    source_and_sink_nodes = []
    nodes_by_net = {}

    for node in clb_graph.nodes.values():
        # Consider only SOURCE and SINK nodes
        if node.type not in [NodeType.SOURCE, NodeType.SINK]:
            continue

        # Split the node path into block and port
        path, port = node.path.rsplit(".", maxsplit=1)

        # Check if the node belongs to this CLB
        if path != block_path:
            continue

        source_and_sink_nodes.append(node)
        port = PathNode.from_string(port)

        # Optionally remap the port
        if port_map is not None:
            key = (port.name, port.index)
            if key in inv_port_map:
                name, index = inv_port_map[key]
                port = PathNode(name, index)

        # Got this port in the source block
        # Find a net for the port pin of the source block and assign it
        net = None
        if port.name in block.ports:
            net = block.find_net_for_port(port.name, port.index)

        # If the port is unconnected then check if there is a defautil value
        # in the map
        if def_map:
            key = (port.name, port.index)
            if not net and key in def_map:
                net = def_map[key]
                logging.debug("    Unconnected port '{}' defaults to {}".format(port, net))

        # Skip unconnected ports
        if not net:
            logging.debug("    Port '{}' is unconnected".format(port))
            continue

        # Assign the net
        node.net = net

        if net not in nodes_by_net:
            nodes_by_net[net] = []
        nodes_by_net[net].append(node)

    # No constraints, finish here
    if constraints is None:
        return

    # Reassign top-level SOURCE and SINK nodes according to the constraints
    for constraint in constraints:
        # Check if the constraint is for this block type
        if constraint.block_type != block_type:
            continue

        # Check if the net is available
        if constraint.net not in nodes_by_net:
            continue

        # Find a node for the destination port of the constraint. Throw an
        # error if not found
        for node in source_and_sink_nodes:
            _, port = node.path.rsplit(".", maxsplit=1)
            port = PathNode.from_string(port)

            if (port.name, port.index) == (constraint.port, constraint.pin):
                port_node = node
                break

        else:
            logging.critical(
                "Cannot find port '{}' of block type '{}'".format(
                    PathNode(constraint.port, constraint.pin).to_string(), block_type
                )
            )
            exit(-1)

        # Check if we are not trying to constraint an input net to an output
        # port or vice-versa.
        node_types = set([node.type for node in nodes_by_net[constraint.net]])
        if port_node.type not in node_types:
            name_map = {NodeType.SINK: "output", NodeType.SOURCE: "input"}

            logging.warning(
                "Cannot constrain {} net '{}' to {} port '{}'".format(
                    name_map[next(iter(node_types))],
                    constraint.net,
                    name_map[port_node.type],
                    PathNode(constraint.port, constraint.pin).to_string(),
                )
            )
            continue

        # Remove the net from any node of the same type as the destination one
        for node in nodes_by_net[constraint.net]:
            if node.type == port_node.type:
                node.net = None

        # Assign the net to the port
        port_node.net = constraint.net
        logging.debug(
            "    Constraining net '{}' to port '{}'".format(
                constraint.net, PathNode(constraint.port, constraint.pin).to_string()
            )
        )


def rotate_truth_table(table, rotation_map):
    """
    Rotates address bits of the truth table of a LUT given a bit map.
    Rotation map key refers to the "new" address while its value to the
    "old" one.
    """

    # Get LUT width, possibly different than the current
    width = max(rotation_map.keys()) + 1

    # Rotate
    new_table = [0 for i in range(2**width)]
    for daddr in range(2**width):
        # Remap address bits
        saddr = 0
        for i in range(width):
            if daddr & (1 << i):
                if i in rotation_map:
                    j = rotation_map[i]
                    saddr |= 1 << j

        assert saddr < len(table), (saddr, len(table))
        new_table[daddr] = table[saddr]

    return new_table


def repack_netlist_cell(eblif, cell, block, src_pbtype, model, rule, def_map=None):
    """
    This function transforms circuit netlist (BLIF / EBLIF) cells to implement
    re-packing.
    """

    # Build a mini-port map for ports of build-in cells (.names, .latch)
    # this is needed to correlate pb_type ports with model ports.
    class_map = {}
    for port in src_pbtype.ports.values():
        if port.cls is not None:
            class_map[port.cls] = port.name

    # Get LUT in port if the cell is a LUT
    lut_in = class_map.get("lut_in", None)

    # Create a new cell
    repacked_cell = Cell(model.name)
    repacked_cell.name = cell.name

    # Copy cell data
    repacked_cell.cname = cell.cname
    repacked_cell.attributes = cell.attributes
    repacked_cell.parameters = cell.parameters

    # Remap port connections
    lut_rotation = {}
    lut_width = 0

    for port, net in cell.ports.items():
        port = PathNode.from_string(port)

        # If the port name refers to a port class then remap it
        port.name = class_map.get(port.name, port.name)

        # Add port index for 1-bit ports
        if port.index is None:
            port.index = 0

        org_index = port.index

        # Undo VPR port rotation
        blk_port = block.ports[port.name]
        if blk_port.rotation_map:
            inv_rotation_map = {v: k for k, v in blk_port.rotation_map.items()}
            port.index = inv_rotation_map[port.index]

        # Remap the port
        if rule.port_map is not None:
            key = (port.name, port.index)
            if key in rule.port_map:
                name, index = rule.port_map[key]
                port = PathNode(name, index)

        # Remove port index for 1-bit ports
        width = model.ports[port.name].width
        if width == 1:
            port.index = None

        repacked_cell.ports[str(port)] = net

        # Update LUT rotation if applicable
        if port.name == lut_in:
            assert port.index not in lut_rotation
            lut_rotation[port.index] = org_index
            lut_width = width

    # If the cell is a LUT then rotate its truth table. Append the rotated
    # truth table as a parameter to the repacked cell.
    if cell.type == "$lut":
        # Build the init parameter
        init = rotate_truth_table(cell.init, lut_rotation)
        init = "".join(["1" if x else "0" for x in init][::-1])

        # Expand the truth table to match the physical LUT width. Do that by
        # repeating the lower part of it until the desired length is attained.
        while (len(init).bit_length() - 1) < lut_width:
            init = init + init

        # Reverse LUT bit order
        init = init[::-1]

        repacked_cell.parameters["LUT"] = init

    # If the cell is a LUT-based const generator append the LUT parameter as
    # well.
    if cell.type == "$const":
        assert lut_width == 0, (cell, lut_width)

        # Assume that the model is a LUT. Take its widest input port and use
        # its width as LUT size.
        max_width = -1
        for port in model.ports.values():
            if port.type == PortType.INPUT:
                if port.width > max_width:
                    max_width = port.width

        init = str(cell.init) * (1 << max_width)
        repacked_cell.parameters["LUT"] = init

    # Process parameters for "adder_lut4"
    if cell.type == "adder_lut4":
        # Remap the Cin mux select to MODE
        if "IN2_IS_CIN" in cell.parameters:
            repacked_cell.parameters["MODE"] = cell.parameters["IN2_IS_CIN"]
            del repacked_cell.parameters["IN2_IS_CIN"]

        # Reverse LUT bit order
        repacked_cell.parameters["LUT"] = repacked_cell.parameters["LUT"][::-1]

    # If the rule contains mode bits then append the MODE parameter to the cell
    if rule.mode_bits:
        repacked_cell.parameters["MODE"] = rule.mode_bits

    # Check for unconnected ports that should be tied to some default nets
    if def_map:
        for key, net in def_map.items():
            port = "{}[{}]".format(*key)
            if port not in repacked_cell.ports:
                repacked_cell.ports[port] = net

    # Remove the old cell and replace it with the new one
    del eblif.cells[cell.name]
    eblif.cells[repacked_cell.name] = repacked_cell

    return repacked_cell


def syncrhonize_attributes_and_parameters(eblif, packed_netlist):
    """
    Syncrhonizes EBLIF cells attributes and parameters with the packed netlist
    leaf blocks by copying them.
    """

    def walk(block):
        # This is a leaf
        if block.is_leaf and not block.is_open:
            if any(block.instance.startswith(inst) for inst in ["outpad", "inpad"]):
                return

            # Find matching cell
            cell = eblif.find_cell(block.name)
            assert cell is not None, block

            # Copy attributes and parameters
            block.attributes = dict(cell.attributes)
            block.parameters = dict(cell.parameters)

        # Recurse
        else:
            for child in block.blocks.values():
                walk(child)

    # Walk over CLBs
    for block in packed_netlist.blocks.values():
        walk(block)


# =============================================================================


def load_repacking_rules(json_root):
    """
    Loads rules for the repacker from a parsed JSON file
    """

    # Get the appropriate section
    json_rules = json_root.get("repacking_rules", None)
    assert json_rules is not None
    assert isinstance(json_rules, list), type(json_rules)

    # Convert the rules
    logging.debug(" Repacking rules:")

    rules = []
    for entry in json_rules:
        assert isinstance(entry, dict), type(entry)

        rule = RepackingRule(
            src=entry["src_pbtype"],
            dst=entry["dst_pbtype"],
            index_map=entry["index_map"],
            port_map=entry["port_map"],
            mode_bits=entry["mode_bits"],
        )
        rules.append(rule)

        logging.debug("  {} -> {}".format(rule.src, rule.dst))

    return rules


def expand_port_maps(rules, clb_pbtypes):
    """
    Expands port maps of repacking rules so that they explicitly specify
    port pins.
    """

    for rule in rules:
        # Get src and dst pb_types
        path = [PathNode.from_string(p) for p in rule.src.split(".")]
        path = [PathNode(p.name, mode=p.mode) for p in path]
        src_pbtype = clb_pbtypes[path[0].name].find(path)
        assert src_pbtype, ".".join([str(p) for p in path])

        path = [PathNode.from_string(p) for p in rule.dst.split(".")]
        path = [PathNode(p.name, mode=p.mode) for p in path]
        dst_pbtype = clb_pbtypes[path[0].name].find(path)
        assert dst_pbtype, ".".join([str(p) for p in path])

        # Expand port map
        port_map = {}
        for src_port, dst_port in rule.port_map.items():
            # Get pin lists
            src_pins = list(src_pbtype.yield_port_pins(src_port))
            dst_pins = list(dst_pbtype.yield_port_pins(dst_port))

            assert len(src_pins) == len(dst_pins), (src_pins, dst_pins)

            # Update port map
            for src_pin, dst_pin in zip(src_pins, dst_pins):
                port_map[src_pin] = dst_pin

        rule.port_map = port_map

    return rules


# =============================================================================


def load_json_constraints(json_root):
    """
    Loads constraints for the repacker from a parsed JSON file
    """

    # Get the appropriate section
    json_constrs = json_root.get("repacking_constraints", None)
    assert json_constrs is not None
    assert isinstance(json_constrs, list), type(json_constrs)

    # Convert to RepackingConstraint objects
    logging.debug(" Repacking constraints:")

    constraints = []
    for json_constr in json_constrs:
        constraint = RepackingConstraint(
            net=json_constr["net"], block_type=json_constr["tile"], port_spec=json_constr["pin"]
        )
        constraints.append(constraint)

        logging.debug("  {}: {}.{}[{}]".format(constraint.net, constraint.block_type, constraint.port, constraint.pin))

    return constraints


# =============================================================================


def load_pcf_constraints(pcf):
    """
    Loads constraints for the repacker from a parsed PCF file
    """

    logging.debug(" Repacking constraints:")

    constraints = []
    for pcf_constr in parse_simple_pcf(pcf):
        if type(pcf_constr).__name__ == "PcfClkConstraint":
            # There are only "clb" and "io" tile types
            # We select the same global clock for
            # each tile where net is used
            constraint = RepackingConstraint(net=pcf_constr.net, block_type="clb", port_spec=pcf_constr.pin)
            constraints.append(constraint)
            logging.debug(
                "  {}: {}.{}[{}]".format(constraint.net, constraint.block_type, constraint.port, constraint.pin)
            )

            constraint = RepackingConstraint(net=pcf_constr.net, block_type="io", port_spec=pcf_constr.pin)
            constraints.append(constraint)
            logging.debug(
                "  {}: {}.{}[{}]".format(constraint.net, constraint.block_type, constraint.port, constraint.pin)
            )

    return constraints


# =============================================================================


def write_packed_netlist(fname, netlist):
    """
    Writes the given packed netlist to an XML file
    """

    xml_tree = ET.ElementTree(netlist.to_etree())
    xml_data = '<?xml version="1.0"?>\n' + ET.tostring(xml_tree, pretty_print=True).decode("utf-8")  # noqa: E127

    with open(fname, "w") as fp:
        fp.write(xml_data)


# =============================================================================


def main():
    # Parse arguments
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument("--vpr-arch", type=str, required=True, help="VPR architecture XML file")
    parser.add_argument("--repacking-rules", type=str, required=True, help="JSON file describing repacking rules")
    parser.add_argument("--json-constraints", type=str, default=None, help="JSON file describing repacking constraints")
    parser.add_argument("--pcf-constraints", type=str, default=None, help="PCF file describing repacking constraints")
    parser.add_argument("--eblif-in", type=str, required=True, help="Input circuit netlist in BLIF/EBLIF format")
    parser.add_argument("--net-in", type=str, required=True, help="Input VPR packed netlist (.net)")
    parser.add_argument("--place-in", type=str, default=None, help="Input VPR placement file (.place)")
    parser.add_argument("--eblif-out", type=str, default=None, help="Output circuit netlist BLIF/EBLIF file")
    parser.add_argument("--net-out", type=str, default=None, help="Output VPR packed netlist (.net) file")
    parser.add_argument("--place-out", type=str, default=None, help="Output VPR placement (.place) file")
    parser.add_argument(
        "--absorb_buffer_luts",
        type=str,
        default="on",
        choices=["on", "off"],
        help="Controls whether buffer LUTs are to be absorbed downstream",
    )
    parser.add_argument("--dump-dot", action="store_true", help="Dump graphviz .dot files for pb_type graphs")
    parser.add_argument(
        "--dump-netlist", action="store_true", help="Dump .eblif files at different stages of EBLIF netlist processing"
    )
    parser.add_argument("--log", type=str, default=None, help="Log file name (def. stdout)")
    parser.add_argument(
        "--log-level",
        type=str,
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        default="WARNING",
        help='Log level (def. "WARNING")',
    )

    args = parser.parse_args()
    init_time = time.perf_counter()

    absorb_buffer_luts = args.absorb_buffer_luts == "on"

    # Setup logging
    logging.basicConfig(
        filename=args.log,
        filemode="w",
        format="%(message)s",
        level=getattr(logging, args.log_level.upper()),
    )

    if args.log is not None:
        logging.getLogger().addHandler(logging.StreamHandler(sys.stdout))

    # Re-assemble and log the commandline
    cmdline = " ".join([shlex.quote(a) for a in sys.argv])
    logging.debug("command line: {}".format(cmdline))

    # Load the VPR architecture
    logging.info("Loading VPR architecture file...")
    xml_tree = ET.parse(args.vpr_arch, ET.XMLParser(remove_blank_text=True))

    # Get CLBs
    xml_clbs = xml_tree.getroot().find("complexblocklist").findall("pb_type")
    xml_clbs = {clb.attrib["name"]: clb for clb in xml_clbs}

    # Build pb_type hierarchy for each CLB
    logging.info("Building pb_type hierarchy...")
    clb_pbtypes = {name: PbType.from_etree(elem) for name, elem in xml_clbs.items()}

    # Build a list of models
    logging.info("Building primitive models...")
    models = {}
    for pb_type in clb_pbtypes.values():
        models.update(Model.collect_models(pb_type))

    # DEBUG
    keys = sorted(list(models.keys()))
    for key in keys:
        logging.debug(" " + str(models[key]))

    # Load the repacking rules
    logging.info("Loading repacking rules...")
    with open(args.repacking_rules, "r") as fp:
        json_root = json.load(fp)

    # Get repacking rules
    repacking_rules = load_repacking_rules(json_root)
    # Expand port maps in repacking rules
    expand_port_maps(repacking_rules, clb_pbtypes)

    # Load the repacking constraints if provided

    if args.json_constraints is not None:
        logging.info("Loading JSON constraints...")

        with open(args.json_constraints, "r") as fp:
            json_root = json.load(fp)
            repacking_constraints = load_json_constraints(json_root)

    else:
        repacking_constraints = []

    if args.pcf_constraints is not None:
        logging.info("Loading PCF constraints...")

        with open(args.pcf_constraints, "r") as fp:
            repacking_constraints.extend(load_pcf_constraints(fp))

    # Load the BLIF/EBLIF file
    logging.info("Loading BLIF/EBLIF circuit netlist...")
    eblif = Eblif.from_file(args.eblif_in)

    # Clean the netlist
    logging.info("Cleaning circuit netlist...")

    if absorb_buffer_luts:
        net_map = netlist_cleaning.absorb_buffer_luts(eblif)
    else:
        net_map = {}

    # Optional dump
    if args.dump_netlist:
        eblif.to_file("netlist.cleaned.eblif")

    # Convert top-level inputs to cells
    eblif.convert_ports_to_cells()

    # Optional dump
    if args.dump_netlist:
        eblif.to_file("netlist.io_cells.eblif")

    # Load the packed netlist XML
    logging.info("Loading VPR packed netlist...")
    net_xml = ET.parse(args.net_in, ET.XMLParser(remove_blank_text=True))
    packed_netlist = PackedNetlist.from_etree(net_xml.getroot())

    # Count blocks
    total_blocks = 0
    for clb_block in packed_netlist.blocks.values():
        total_blocks += clb_block.count_leafs()
    logging.debug(" {} leaf blocks".format(total_blocks))

    init_time = time.perf_counter() - init_time
    repack_time = time.perf_counter()

    # Check if the repacking constraints do not refer to any non-existent nets
    if repacking_constraints:
        logging.info("Validating constraints...")

        all_nets = set()
        for clb_block in packed_netlist.blocks.values():
            all_nets |= clb_block.get_nets()

        constrained_nets = set([c.net for c in repacking_constraints])
        invalid_nets = constrained_nets - all_nets

        if invalid_nets:
            logging.critical(" Error: constraints refer to nonexistent net(s): {}".format(", ".join(invalid_nets)))
            exit(-1)

    # Process netlist CLBs
    logging.info("Processing CLBs...")

    leaf_block_names = {}

    route_through_net_ids = {}

    repacked_clb_count = 0
    repacked_block_count = 0

    for clb_block in packed_netlist.blocks.values():
        logging.debug(" " + str(clb_block))

        # Remap block and net names
        clb_block.rename_nets(net_map)

        # Find a corresponding root pb_type (complex block) in the architecture
        clb_pbtype = clb_pbtypes.get(clb_block.type, None)
        if clb_pbtype is None:
            logging.error("Complex block type '{}' not found in the VPR arch".format(clb_block.type))
            exit(-1)

        # Identify and fixup route-throu LUTs
        logging.debug("  Identifying route-throu LUTs...")
        net_pairs = fixup_route_throu_luts(clb_block, route_through_net_ids)
        insert_buffers(net_pairs, eblif, clb_block)

        # Identify blocks to repack. Continue to next CLB if there are none
        logging.debug("  Identifying blocks to repack...")
        blocks_to_repack = identify_blocks_to_repack(clb_block, repacking_rules)
        if not blocks_to_repack:
            continue

        # For each block to be repacked identify its destination candidate(s)
        logging.debug("  Identifying repack targets...")
        iter_list = list(blocks_to_repack)
        blocks_to_repack = []
        for block, rule in iter_list:
            # Remap index of the destination block pointed by the path of the
            # rule.
            blk_path = block.get_path()
            blk_path = [PathNode.from_string(p) for p in blk_path.split(".")]
            dst_path = rule.dst
            dst_path = [PathNode.from_string(p) for p in dst_path.split(".")]

            if dst_path[-1].index is None:
                dst_path[-1].index = rule.remap_pb_type_index(blk_path[-1].index)

            blk_path = ".".join([str(p) for p in blk_path])
            dst_path = ".".join([str(p) for p in dst_path])

            # Fix the part of the destination block path so that it matches the
            # path of the block to be remapped
            arch_path = fix_block_path(blk_path, dst_path)

            # Identify target candidates
            candidates = identify_repack_target_candidates(clb_pbtype, arch_path)
            assert candidates, (block, arch_path)

            logging.debug("   {} ({})".format(str(block), rule.src))
            for path, pbtype_xml in candidates:
                logging.debug("    " + str(path))

            # No candidates
            if not candidates:
                logging.critical("No repack target found!")
                exit(-1)

            # There must be only a single repack target per block
            if len(candidates) > 1:
                logging.critical("Multiple repack targets found! {}".format(candidates))
                exit(-1)

            # Store concrete correspondence
            # (packed netlist block, repacking rule, (target path, target pb_type))
            blocks_to_repack.append((block, rule, candidates[0]))

        if not blocks_to_repack:
            continue

        # Check for conflicts
        repack_targets = set()
        for block, rule, (path, pbtype) in blocks_to_repack:
            if path in repack_targets:
                logging.error("Multiple blocks are to be repacked into '{}'".format(path))
            repack_targets.add(path)

        # Stats
        repacked_clb_count += 1
        repacked_block_count += len(blocks_to_repack)

        # Repack the circuit netlist
        logging.debug("  Repacking circuit netlist...")
        for src_block, rule, (dst_path, dst_pbtype) in blocks_to_repack:
            logging.debug("   " + str(src_block))

            # Find the original pb_type
            src_path = src_block.get_path(with_indices=False)
            src_pbtype = clb_pbtype.find(src_path)
            assert src_pbtype is not None, src_path

            # Get the destination BLIF model
            assert dst_pbtype.blif_model is not None, dst_pbtype.name
            dst_blif_model = dst_pbtype.blif_model.split(maxsplit=1)[-1]

            if dst_blif_model in [".input", ".output"]:
                continue

            # Get the model object
            assert dst_blif_model in models, dst_blif_model
            model = models[dst_blif_model]

            # Find the cell in the netlist
            assert src_block.name in eblif.cells, src_block.name
            cell = eblif.cells[src_block.name]

            # Store the leaf block name so that it can be restored after
            # repacking
            leaf_block_names[dst_path] = cell.name

            # Repack it
            repack_netlist_cell(
                eblif,
                cell,
                src_block,
                src_pbtype,
                model,
                rule,
            )

        # Build a pb routing graph for this CLB
        logging.debug("  Building pb_type routing graph...")
        clb_xml = xml_clbs[clb_block.type]
        graph = Graph.from_etree(clb_xml, clb_block.instance)

        # Dump original packed netlist graph as graphvis .dot file
        if args.dump_dot:
            load_clb_nets_into_pb_graph(clb_block, graph)
            fname = "graph_original_{}.dot".format(clb_block.instance)
            with open(fname, "w") as fp:
                fp.write(graph.dump_dot(color_by="net", nets_only=True))
            graph.clear_nets()

        # Annotate source and sinks with nets
        logging.debug("  Annotating net endpoints...")

        # For the CLB
        logging.debug("   " + str(clb_block))
        annotate_net_endpoints(clb_graph=graph, block=clb_block, constraints=repacking_constraints)

        # For repacked leafs
        for block, rule, (path, dst_pbtype) in blocks_to_repack:
            logging.debug("   " + str(block))

            # Get the destination BLIF model
            assert dst_pbtype.blif_model is not None, dst_pbtype.name
            dst_blif_model = dst_pbtype.blif_model.split(maxsplit=1)[-1]

            # Annotate
            annotate_net_endpoints(clb_graph=graph, block=block, block_path=path, port_map=rule.port_map)

        # Initialize router
        logging.debug("  Initializing router...")
        router = Router(graph)

        # There has to be at least one net in the block after repacking
        assert router.nets, "No nets"

        # Route
        logging.debug("  Routing...")
        router.route_nets(debug=True)

        # Build packed netlist CLB from the graph
        logging.debug("  Rebuilding CLB netlist...")
        repacked_clb_block = build_packed_netlist_from_pb_graph(graph)
        repacked_clb_block.rename_cluster(clb_block.name)

        # Restore names of leaf blocks
        for src_block, rule, (dst_path, dst_pbtype) in blocks_to_repack:
            if dst_path in leaf_block_names:
                search_path = dst_path.split(".", maxsplit=1)[1]
                dst_block = repacked_clb_block.get_block_by_path(search_path)
                assert dst_block is not None, dst_path

                name = leaf_block_names[dst_path]
                logging.debug("   renaming leaf block {} to {}".format(dst_block, name))
                dst_block.name = name

        # Replace the CLB
        packed_netlist.blocks[clb_block.instance] = repacked_clb_block

        # Dump repacked packed netlist graph as graphviz .dot file
        if args.dump_dot:
            fname = "graph_repacked_{}.dot".format(clb_block.instance)
            with open(fname, "w") as fp:
                fp.write(graph.dump_dot(color_by="net", nets_only=True))

    # Optional dump
    if args.dump_netlist:
        eblif.to_file("netlist.repacked.eblif")
        write_packed_netlist("netlist.repacked.net", packed_netlist)

    # Synchronize packed netlist attributes and parameters with EBLIF
    syncrhonize_attributes_and_parameters(eblif, packed_netlist)

    repack_time = time.perf_counter() - repack_time
    writeout_time = time.perf_counter()

    # FIXME: The below code absorbs buffer LUTs because it couldn't be done
    # in the beginning to preserve output names. However the code has evolved
    # and now should correctly handle absorption of output nets into input
    # nets not only the opposite as it did before. So theoretically the buffer
    # absorption below may be removed and the invocation at the beginning of
    # the flow changed to use outputs=True.

    # Convert cells into top-level ports
    eblif.convert_cells_to_ports()

    # Clean the circuit netlist again. Need to do it here again as LUT buffers
    # driving top-level inputs couldn't been swept before repacking as it
    # would cause top-level port renaming.
    logging.info("Cleaning repacked circuit netlist...")
    if absorb_buffer_luts:
        net_map = netlist_cleaning.absorb_buffer_luts(eblif, outputs=True)

        # Synchronize packed netlist net names
        for block in packed_netlist.blocks.values():
            block.rename_nets(net_map)

    # Optional dump
    if args.dump_netlist:
        eblif.to_file("netlist.repacked_and_cleaned.eblif")

    # Write the circuit netlist
    logging.info("Writing EBLIF circuit netlist...")
    fname = args.eblif_out if args.eblif_out else "repacked.eblif"
    eblif.to_file(fname, consts=False)

    # Compute SHA256 digest of the EBLIF file and store it in the packed
    # netlist.
    with open(fname, "rb") as fp:
        digest = hashlib.sha256(fp.read()).hexdigest()
    packed_netlist.netlist_id = "SHA256:" + digest

    # Write the packed netlist
    logging.info("Writing VPR packed netlist...")
    net_out_fname = args.net_out if args.net_out else "repacked.net"
    write_packed_netlist(net_out_fname, packed_netlist)

    writeout_time = time.perf_counter() - writeout_time

    # Read and patch SHA and packed netlist name in the VPR placement file
    # if given
    if args.place_in:
        logging.info("Patching VPR placement file...")

        # Compute .net file digest
        with open(net_out_fname, "rb") as fp:
            net_digest = hashlib.sha256(fp.read()).hexdigest()

        # Read placement
        with open(args.place_in, "r") as fp:
            placement = fp.readlines()

        # Find the header line
        for i in range(len(placement)):
            if placement[i].startswith("Netlist_File:"):
                # Replace the header
                placement[i] = "Netlist_File: {} Netlist_ID: {}\n".format(
                    os.path.basename(net_out_fname), "SHA256:" + net_digest
                )
                break
        else:
            logging.warn(" The placement file '{}' has no header!".format(args.place_in))

        # Write the patched placement
        fname = args.place_out if args.place_out else "repacked.place"
        with open(fname, "w") as fp:
            fp.writelines(placement)

    # Count blocks
    total_blocks = 0
    for clb_block in packed_netlist.blocks.values():
        total_blocks += clb_block.count_leafs()

    # Print statistics
    logging.info("Finished.")

    logging.info("")
    logging.info("Initialization time: {:.2f}s".format(init_time))
    logging.info("Repacking time     : {:.2f}s".format(repack_time))
    logging.info("Finishing time     : {:.2f}s".format(writeout_time))
    logging.info("Repacked CLBs      : {}".format(repacked_clb_count))
    logging.info("Repacked blocks    : {}".format(repacked_block_count))
    logging.info("Total blocks       : {}".format(total_blocks))


# =============================================================================

if __name__ == "__main__":
    main()
