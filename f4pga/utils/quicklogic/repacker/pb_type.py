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
Utilities for representing pb_type hierarchy as defined in VPR architecture
"""
import re
from copy import deepcopy
from enum import Enum

from f4pga.utils.quicklogic.repacker.arch_xml_utils import is_leaf_pbtype

from f4pga.utils.quicklogic.repacker.block_path import PathNode

# =============================================================================


class PortType(Enum):
    """
    Type and direction of a pb_type port.
    """

    UNSPEC = 0
    INPUT = 1
    OUTPUT = 2
    CLOCK = 3

    @staticmethod
    def from_string(s):
        """
        Convert a string to its corresponding enumerated value
        """
        s = s.lower()

        if s == "input":
            return PortType.INPUT
        elif s == "output":
            return PortType.OUTPUT
        elif s == "clock":
            return PortType.CLOCK
        else:
            assert False, s


class Port:
    """
    A port of pb_type
    """

    def __init__(self, type, name, width=1, cls=None):
        """
        Basic constructor
        """
        self.type = type
        self.name = name
        self.width = width
        self.cls = cls

    @staticmethod
    def from_etree(elem):
        """
        Create the object from its ElementTree representation
        """
        assert elem.tag in ["input", "output", "clock"], elem.tag

        # Create the port
        port = Port(
            type=PortType.from_string(elem.tag),
            name=elem.attrib["name"],
            width=int(elem.get("num_pins", "1")),
            cls=elem.get("port_class", None),
        )

        return port

    def yield_pins(self, range_spec=None):
        """
        Yields pin names given index range specification. If the range is
        not given then yields all pins.
        """

        # Selected pins
        if range_spec is not None:
            # TODO: Compile the regex upfront
            match = re.fullmatch(r"((?P<i1>[0-9]+):)?(?P<i0>[0-9]+)", range_spec)
            assert match is not None, range_spec

            i0 = int(match.group("i0"))
            i1 = int(match.group("i1")) if match.group("i1") else None

            assert i0 < self.width, range_spec

            # Range
            if i1 is not None:
                assert i1 < self.width, range_spec

                if i1 > i0:
                    indices = range(i0, i1 + 1)
                elif i1 < i0:
                    # Do not yield in reverse order when indices are reversed
                    indices = range(i1, i0 + 1)
                else:
                    indices = [i0]

            # Single number
            else:
                indices = [i0]

        # All pins
        else:
            indices = range(self.width)

        # Yield names
        for i in indices:
            yield (self.name, i)


# =============================================================================


class Model:
    """
    A leaf cell model.

    VPR architecture XML does not store port widths along with models so
    here we build the list of models from leaf pb_types.
    """

    def __init__(self, name):
        self.name = name
        self.ports = {}

    @property
    def blif_model(self):
        """
        Returns a BLIF model statement for this model.
        """
        if self.name[0] != ".":
            return ".subckt {}".format(self.name)
        return self.name

    @staticmethod
    def collect_models(root_pbtype):
        """
        Recursively walks over the pb_type hierarchy and collects models
        """

        models = {}

        def walk(pb_type):
            # This is a mode, recurse
            if isinstance(pb_type, Mode):
                for child in pb_type.pb_types.values():
                    walk(child)

            # This is a pb_type. Make a model if it is a leaf
            elif isinstance(pb_type, PbType):
                # Not a leaf, recurse for modes
                if not pb_type.is_leaf:
                    for mode in pb_type.modes.values():
                        walk(mode)
                    return

                # Get BLIF model
                assert pb_type.blif_model is not None, pb_type.name
                blif_model = pb_type.blif_model.split(maxsplit=1)[-1]

                # FIXME: Skip built-ins for now
                if blif_model[0] == ".":
                    return

                # Already have that one
                # TODO: Check if ports match!
                if blif_model in models:
                    return

                # Build the model
                model = Model(blif_model)
                model.ports = deepcopy(pb_type.ports)
                models[model.name] = model

            else:
                assert False, type(pb_type)

        # Walk from the given root pb_type and create models
        walk(root_pbtype)
        return models

    def __str__(self):
        string = self.name
        for port in self.ports.values():
            string += " {}:{}[{}:0]".format(port.type.name[0].upper(), port.name, port.width - 1)
        return string

    def __repr__(self):
        return str(self)


# =============================================================================


class PbType:
    """
    A pb_type
    """

    def __init__(self, name, num_pb=1, cls=None):
        """
        Basic constructor
        """
        self.name = name
        self.num_pb = num_pb
        self.cls = cls
        self.blif_model = None

        # Parent (a Mode or None)
        self.parent = None
        # Modes (indexed by name)
        self.modes = {}

        # Ports (indexed by name)
        self.ports = {}

    @property
    def is_leaf(self):
        """
        Returns True if this pb_type is a leaf
        """
        if "default" in self.modes and len(self.modes) == 1:
            return len(self.modes["default"].pb_types) == 0

        return False

    @staticmethod
    def from_etree(elem):
        """
        Create the object from its ElementTree representation
        """
        assert elem.tag == "pb_type", elem.tag

        # Create the pb_type
        name = elem.attrib["name"]
        num_pb = int(elem.get("num_pb", "1"))
        cls = elem.get("class", None)

        pb_type = PbType(name, num_pb, cls)

        # BLIF model
        pb_type.blif_model = elem.get("blif_model", None)

        # Identify all modes. If there is none then add the default
        # implicit one.
        xml_modes = {x.attrib["name"]: x for x in elem.findall("mode")}
        if not xml_modes:
            xml_modes = {"default": elem}

        # Build modes
        pb_type.modes = {}
        for name, xml_mode in xml_modes.items():
            mode = Mode.from_etree(xml_mode)
            mode.parent = pb_type
            pb_type.modes[mode.name] = mode

        # Build ports
        for xml_port in elem:
            if xml_port.tag in ["input", "output", "clock"]:
                port = Port.from_etree(xml_port)
                pb_type.ports[port.name] = port

        # This is a native LUT leaf pb_type. Add one more level of hierarchy
        if is_leaf_pbtype(elem) and cls == "lut":
            # Rename the default mode so that it matches the pb_type name
            mode = pb_type.modes["default"]
            mode.name = pb_type.name
            pb_type.modes = {mode.name: mode}

            # Add a child pb_type named "lut" to the mode
            child = PbType(name="lut", cls="lut")
            child.blif_model = ".names"
            child.parent = mode
            mode.pb_types[child.name] = child

            # Add a default mode to the child pb_type
            mode = Mode("default")
            mode.parent = child
            child.modes[mode.name] = mode

            # Copy ports from the current pb_type
            child.ports = deepcopy(pb_type.ports)

        return pb_type

    def yield_port_pins(self, port_spec):
        """
        Given a port specification string yields its pin names
        """

        # TODO: Compile the regex upfront
        match = re.fullmatch(r"(?P<port>[^\s\[\]\.]+)(\[(?P<bits>[^\s\[\]]+)\])?", port_spec)
        assert match is not None, port_spec

        port = match.group("port")
        bits = match.group("bits")

        # Find the port
        assert port in self.ports, (self.name, port)
        port = self.ports[port]

        # Yield the bits
        yield from port.yield_pins(bits)

    def find(self, path):
        """
        Finds a pb_type or a mode given its hierarchical path.
        """

        # Split the path or assume this is an already splitted list.
        if isinstance(path, str):
            path = path.split(".")
            path = [PathNode.from_string(p) for p in path]
        else:
            assert isinstance(path, list), type(path)

        # Walk the hierarchy along the path
        pbtype = self
        while True:
            # Pop a node from the path
            part = path[0]
            path = path[1:]

            # The path node must not have an index
            assert part.index is None, part

            # Check name
            if part.name != pbtype.name:
                break

            # Explicit mode
            if part.mode is not None:
                if part.mode not in pbtype.modes:
                    break
                mode = pbtype.modes[part.mode]

                # No more path, return the mode
                if not path:
                    return mode

            # Mode not given
            else:
                # No more path, return the pb_type
                if not path:
                    return pbtype

                # Get the implicit mode
                if len(pbtype.modes) > 1:
                    break
                mode = next(iter(pbtype.modes.values()))

            # Find the child pb_type
            part = path[0]
            if part.name not in mode.pb_types:
                break

            pbtype = mode.pb_types[part.name]

        # Not found
        return None


class Mode:
    """
    A mode of a pb_type
    """

    def __init__(self, name):
        """
        Basic constructor
        """
        self.name = name

        # Parent (a PbType or None)
        self.parent = None
        # pb_types indexed by names
        self.pb_types = {}

    def yield_children(self):
        """
        Yields all child pb_types and their indices taking into account num_pb.
        """
        for child in self.pb_types.values():
            for i in range(child.num_pb):
                yield child, i

    @staticmethod
    def from_etree(elem):
        """
        Create the object from its ElementTree representation
        """
        assert elem.tag in ["mode", "pb_type"], elem.tag

        # This element refers to a pb_type so it is the default mode
        if elem.tag == "pb_type":
            name = "default"
        else:
            name = elem.attrib["name"]

        # Create the mode
        mode = Mode(name)

        # Build child pb_types
        for xml_pbtype in elem.findall("pb_type"):
            pb_type = PbType.from_etree(xml_pbtype)
            pb_type.parent = mode
            mode.pb_types[pb_type.name] = pb_type

        return mode
