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
Utilities for handling VTR packed netlist (.net) data

VPR packed netlist format specification:
    https://docs.verilogtorouting.org/en/latest/vpr/file_formats/#packed-netlist-format-net
"""
import re
import lxml.etree as ET

from f4pga.aux.utils.quicklogic.repacker.block_path import PathNode

# =============================================================================


class Connection:
    """
    A class representing a connection of a port pin. For output ports it
    refers to child/sibling block, port and pin while for input ports it refers
    to the parent/sibling block, port and pin.
    """

    # A regex for parsing connection specification
    REGEX = re.compile(r"(?P<driver>\S+)\.(?P<port>\S+)\[(?P<pin>[0-9]+)\]->" r"(?P<interconnect>\S+)")

    def __init__(self, driver, port, pin, interconnect):
        """
        Basic constructor
        """
        self.driver = driver
        self.port = port
        self.pin = pin
        self.interconnect = interconnect

    @staticmethod
    def from_string(spec):
        """
        Parses a specification string. Returns a Connection object

        >>> Connection.from_string("parent.A[3]->interconnect")
        parent.A[3]->interconnect
        >>> Connection.from_string("parent.A->interconnect")
        Traceback (most recent call last):
        ...
        AssertionError: parent.A->interconnect
        >>> Connection.from_string("parent.A[3]")
        Traceback (most recent call last):
        ...
        AssertionError: parent.A[3]
        >>> Connection.from_string("Something")
        Traceback (most recent call last):
        ...
        AssertionError: Something
        """
        assert isinstance(spec, str)

        # Try match
        match = Connection.REGEX.fullmatch(spec)
        assert match is not None, spec

        # Extract data
        return Connection(
            driver=match.group("driver"),
            port=match.group("port"),
            pin=int(match.group("pin")),
            interconnect=match.group("interconnect"),
        )

    def to_string(self):
        """
        Builds a specification string that can be stored in packed netlist
        """
        return "{}.{}[{}]->{}".format(self.driver, self.port, self.pin, self.interconnect)

    def __str__(self):
        return self.to_string()

    def __repr__(self):
        return self.to_string()


# =============================================================================


class Port:
    """
    A class representing a block port. Stores port information such as type
    (direction), bus width and its connections.
    """

    def __init__(self, name, type, width=1, connections=None):
        """
        Basic constructor
        """
        self.name = name
        self.type = type
        self.width = width

        # Sanity check provided port connections
        if connections is not None:
            assert isinstance(connections, dict)

            # Check each entry
            for pin, conn in connections.items():
                assert isinstance(pin, int), pin
                assert pin < self.width, (pin, width)
                assert isinstance(conn, Connection) or isinstance(conn, str), pin

            self.connections = connections

        else:
            self.connections = {}

        # Rotation map
        self.rotation_map = None

    @staticmethod
    def from_etree(elem, type):
        """
        Builds a port class from the packed netlist (XML) representation.
        """
        assert elem.tag == "port", elem.tag
        name = elem.attrib["name"]

        conn = elem.text.strip().split()
        width = len(conn)

        # Remove open connections
        conn = {i: conn[i] for i in range(width) if conn[i] != "open"}

        # Build connection objects. Do that only for ports that specify a
        # connection to another port. Otherwise treat the name as a net name.
        for key in conn.keys():
            if "->" in conn[key]:
                conn[key] = Connection.from_string(conn[key])

        return Port(name, type, width, conn)

    def to_etree(self):
        """
        Converts the port representation to the packed netlist (XML)
        representation.
        """

        # Format connections
        text = []
        for i in range(self.width):
            if i in self.connections:
                text.append(str(self.connections[i]))
            else:
                text.append("open")

        elem = ET.Element("port", attrib={"name": self.name})
        elem.text = " ".join(text)
        return elem

    def __str__(self):
        """
        Returns a user-readable description string
        """
        return "{}[{}:0] ({})".format(self.name, self.width - 1, self.type[0].upper())

    def __repr__(self):
        return str(self)


# =============================================================================


class Block:
    """
    A hierarchical block of a packed netlist.
    """

    def __init__(self, name, instance, mode=None, parent=None):
        # Basic attributes
        self.name = name
        self.instance = instance
        self.mode = mode

        # Identify the block type. FIXME: Use a regex here
        self.type = instance.split("[", maxsplit=1)[0]

        # Ports indexed by names
        self.ports = {}

        # Parent block
        self.parent = parent

        # Child blocks indexed by instance
        self.blocks = {}

        # Leaf block attributes and parameters
        self.attributes = {}
        self.parameters = {}

    @staticmethod
    def from_etree(elem):
        """
        Builds a block class from the packed netlist (XML) representation.
        """
        assert elem.tag == "block", elem.tag

        # Create the block with basic attributes
        block = Block(name=elem.attrib["name"], instance=elem.attrib["instance"], mode=elem.get("mode", "default"))

        # Parse ports
        rotation_maps = {}
        for tag in ["inputs", "outputs", "clocks"]:
            port_type = tag[:-1]

            xml_ports = elem.find(tag)
            if xml_ports is not None:
                for xml_port in xml_ports:
                    # Got a port rotation map
                    if xml_port.tag == "port_rotation_map":
                        port_name = xml_port.attrib["name"]
                        rotation = xml_port.text

                        # Parse the map
                        rotation_map = {}
                        for i, j in enumerate(rotation.strip().split()):
                            if j != "open":
                                rotation_map[i] = int(j)

                        # Store it to be later associated with a port
                        rotation_maps[port_name] = rotation_map

                    # Got a port
                    else:
                        port = Port.from_etree(xml_port, port_type)
                        block.ports[port.name] = port

        # Associate rotation maps with ports
        for port_name, rotation_map in rotation_maps.items():
            assert port_name in block.ports, port_name
            block.ports[port_name].rotation_map = rotation_map

        # Recursively parse sub-blocks
        for xml_block in elem.findall("block"):
            sub_block = Block.from_etree(xml_block)

            sub_block.parent = block
            block.blocks[sub_block.instance] = sub_block

        # Parse attributes and parameters
        for tag, data in zip(["attributes", "parameters"], [block.attributes, block.parameters]):
            # Find the list
            xml_list = elem.find(tag)
            if xml_list is not None:
                # Only a leaf block can have attributes / parameters
                assert block.is_leaf, "Non-leaf block '{}' with {}".format(block.instance, tag)

                # Parse
                sub_tag = tag[:-1]
                for xml_item in xml_list.findall(sub_tag):
                    data[xml_item.attrib["name"]] = xml_item.text

        return block

    def to_etree(self):
        """
        Converts the block representation to the packed netlist (XML)
        representation.
        """

        # Base block element
        attrib = {
            "name": self.name,
            "instance": self.instance,
        }
        if not self.is_leaf:
            attrib["mode"] = self.mode if self.mode is not None else "default"

        elem = ET.Element("block", attrib)

        # If this is an "open" block then skip the remaining tags
        if self.name == "open":
            return elem

        # Attributes / parameters
        if self.is_leaf:
            for tag, data in zip(["attributes", "parameters"], [self.attributes, self.parameters]):
                xml_list = ET.Element(tag)

                sub_tag = tag[:-1]
                for key, value in data.items():
                    xml_item = ET.Element(sub_tag, {"name": key})
                    xml_item.text = value
                    xml_list.append(xml_item)

                elem.append(xml_list)

        # Ports
        for tag in ["inputs", "outputs", "clocks"]:
            xml_ports = ET.Element(tag)
            port_type = tag[:-1]

            keys = self.ports.keys()
            for key in keys:
                port = self.ports[key]
                if port.type == port_type:
                    # Encode port
                    xml_port = port.to_etree()
                    xml_ports.append(xml_port)

                    # Rotation map
                    if port.rotation_map:
                        # Encode
                        rotation = []
                        for i in range(port.width):
                            rotation.append(str(port.rotation_map.get(i, "open")))

                        # Make an element
                        xml_rotation_map = ET.Element("port_rotation_map", {"name": port.name})
                        xml_rotation_map.text = " ".join(rotation)
                        xml_ports.append(xml_rotation_map)

            elem.append(xml_ports)

        # Recurse
        keys = self.blocks.keys()
        for key in keys:
            xml_block = self.blocks[key].to_etree()
            elem.append(xml_block)

        return elem

    @property
    def is_leaf(self):
        """
        Returns True when the block is a leaf block
        """
        return len(self.blocks) == 0

    @property
    def is_open(self):
        """
        Returns True when the block is open
        """
        return self.name == "open"

    @property
    def is_route_throu(self):
        """
        Returns True when the block is a route-throu native LUT
        """

        # VPR stores route-through LUTs as "open" blocks with mode set to
        # "wire".
        return self.is_leaf and self.name == "open" and self.mode == "wire"

    def get_path(self, with_indices=True, with_modes=True, default_modes=True):
        """
        Returns the full path to the block. When with_indices is True then
        index suffixes '[<index>]' are appended to block types. When
        with_modes is True then mode suffixes '[<mode>]' are appended. The
        default_modes flag controls appending suffixes for default modes.
        """
        path = []
        block = self

        # Walk towards the tree root
        while block is not None:
            # Type or type with index (instance)
            if with_indices:
                node = block.instance
            else:
                node = block.type

            # Mode suffix
            if not block.is_leaf and with_modes:
                if block.mode != "default" or default_modes:
                    node += "[{}]".format(block.mode)

            # Prepend
            path = [node] + path

            # Go up
            block = block.parent

        return ".".join(path)

    def rename_cluster(self, name):
        """
        Renames this block and all its children except leaf blocks
        """

        def walk(block):
            if not block.is_leaf and not block.is_open:
                block.name = name

            for child in block.blocks.values():
                walk(child)

        walk(self)

    def rename_nets(self, net_map):
        """
        Renames all nets and leaf blocks that drive them according to the
        given map.
        """

        def walk(block):
            # Rename nets in port connections. Check whether the block itself
            # should be renamed as well (output pads need to be).
            rename_block = block.name.startswith("out:")

            for port in block.ports.values():
                for pin, conn in port.connections.items():
                    if isinstance(conn, str):
                        port.connections[pin] = net_map.get(conn, conn)

                        if port.type == "output":
                            rename_block = True

            # Rename the leaf block if necessary
            if block.is_leaf and not block.is_open and rename_block:
                if block.name in net_map:
                    block.name = net_map[block.name]
                elif block.name.startswith("out:"):
                    key = block.name[4:]
                    if key in net_map:
                        block.name = "out:" + net_map[key]

            # Recurse
            for child in block.blocks.values():
                walk(child)

        walk(self)

    def get_neighboring_block(self, instance):
        """
        Returns a neighboring block given in the vicinity of the current block
        given an instance name. The block can be:

         - This block,
         - A child,
         - The parent,
         - A sibling (the parent's child).
        """

        # Strip index. FIXME: Use a regex here.
        block_type = instance.split("[", maxsplit=1)[0]

        # Check self
        if self.instance == instance:
            return self

        # Check children
        if instance in self.blocks:
            return self.blocks[instance]

        # Check parent and siblings
        if self.parent is not None:
            # Parent
            if self.parent.type == block_type:
                return self.parent

            # Siblings
            if instance in self.parent.blocks:
                return self.parent.blocks[instance]

        return None

    def find_net_for_port(self, port, pin):
        """
        Finds net for the given port name and pin index of the block.
        """

        # Get the port
        assert port in self.ports, (self.name, self.instance, (port, pin))
        port = self.ports[port]

        # Unconnected
        if pin not in port.connections:
            return None

        # Get the pin connection
        conn = port.connections[pin]

        # The connection refers to a net directly
        if isinstance(conn, str):
            return conn

        # Get driving block
        block = self.get_neighboring_block(conn.driver)
        assert block is not None, (self.instance, conn.driver)

        # Recurse
        return block.find_net_for_port(conn.port, conn.pin)

    def get_nets(self):
        """
        Returns all nets that are present in this block and its children
        """

        nets = set()

        # Recursive walk function
        def walk(block):
            # Examine block ports
            for port in block.ports.values():
                for pin in range(port.width):
                    net = block.find_net_for_port(port.name, pin)
                    if net:
                        nets.add(net)

        # Get the nets
        walk(self)
        return nets

    def get_block_by_path(self, path):
        """
        Returns a child block given its hierarchical path. The path must not
        include the current block.

        The path may or may not contain modes. When a mode is given it will
        be used for matching. The path must contain indices.
        """

        def walk(block, parts):
            # Check if instance matches
            instance = "{}[{}]".format(parts[0].name, parts[0].index)
            if block.instance != instance:
                return None

            # Check if operating mode matches
            if parts[0].mode is not None:
                if block.mode != parts[0].mode:
                    return None

            # Next
            parts = parts[1:]

            # No more path parts, this is the block
            if not parts:
                return block

            # Find child block by its instance and recurse
            instance = "{}[{}]".format(parts[0].name, parts[0].index)
            if instance in block.blocks:
                return walk(block.blocks[instance], parts)

            return None

        # Prepend self to the path
        path = "{}[{}]".format(self.instance, self.mode) + "." + path

        # Split and parse the path
        path = path.split(".")
        path = [PathNode.from_string(p) for p in path]

        # Find the child
        return walk(self, path)

    def count_leafs(self):
        """
        Counts all non-open leaf blocks
        """

        def walk(block, count=0):
            # This is a non-ope leaf, count it
            if block.is_leaf and not block.is_open:
                count += 1

            # This is a non-leaf block. Recurse
            if not block.is_leaf:
                for child in block.blocks.values():
                    count += walk(child)

            return count

        # Recursive walk and count
        return walk(self)

    def __str__(self):
        """
        Returns a user-readable description string
        """
        ref = self.instance
        if self.mode is not None:
            ref += "[{}]".format(self.mode)
        ref += " ({})".format(self.name)
        return ref

    def __repr__(self):
        return str(self)


# =============================================================================


class PackedNetlist:
    """
    A VPR Packed netlist representation.

    The packed netlist is organized as one huge block representing the whole
    FPGA with all placeable blocks (CLBs) as its children. Here we store the
    top-level block implicitly so all blocks mentioned in a PackedNetlist
    instance refer to individual placeable CLBs.
    """

    def __init__(self):
        """
        Basic constructor
        """

        # Architecture and atom netlist ids
        self.arch_id = None
        self.netlist_id = None

        # Top-level block name and instance
        self.name = None
        self.instance = None

        # Top-level ports (net names)
        self.ports = {
            "inputs": [],
            "outputs": [],
            "clocks": [],
        }

        # CLBs
        self.blocks = {}

    @staticmethod
    def from_etree(root):
        """
        Reads the packed netlist from the given element tree
        """
        assert root.tag == "block", root.tag

        netlist = PackedNetlist()
        netlist.name = root.attrib["name"]
        netlist.instance = root.attrib["instance"]

        netlist.arch_id = root.get("architecture_id", None)
        netlist.netlist_id = root.get("atom_netlist_id", None)

        # Parse top-level ports
        for tag in ["inputs", "outputs", "clocks"]:
            xml_ports = root.find(tag)
            if xml_ports is not None and xml_ports.text:
                netlist.ports[tag] = xml_ports.text.strip().split()

        # Parse CLBs
        for xml_block in root.findall("block"):
            block = Block.from_etree(xml_block)
            netlist.blocks[block.instance] = block

        return netlist

    def to_etree(self):
        """
        Builds an element tree (XML) that represents the packed netlist
        """

        # Top-level root block
        attr = {
            "name": self.name,
            "instance": self.instance,
        }

        if self.arch_id is not None:
            attr["architecture_id"] = self.arch_id
        if self.netlist_id is not None:
            attr["atom_netlist_id"] = self.netlist_id

        root = ET.Element("block", attr)

        # Top-level ports
        for tag in ["inputs", "outputs", "clocks"]:
            xml_ports = ET.Element(tag)
            xml_ports.text = " ".join(self.ports[tag])
            root.append(xml_ports)

        # CLB blocks
        keys = self.blocks.keys()
        for key in keys:
            xml_block = self.blocks[key].to_etree()
            root.append(xml_block)

        return root
