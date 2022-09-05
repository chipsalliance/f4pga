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
A number of utility functions useful for traversing pb_type hierarchy as
defined in VPR architecture XML file.
"""
import re

import lxml.etree as ET

# =============================================================================


def is_leaf_pbtype(xml_pbtype):
    """
    Returns true when the given pb_type is a leaf.
    """
    assert xml_pbtype.tag == "pb_type", xml_pbtype.tag
    return "blif_model" in xml_pbtype.attrib


def get_parent_pb(xml_pbtype):
    """
    Returns a parent pb_type of the given one or none if it is a top-level
    complex block
    """
    assert xml_pbtype.tag in ["pb_type", "mode", "interconnect"], xml_pbtype.tag

    # Get immediate parent
    xml_parent = xml_pbtype.getparent()

    # We've hit the end
    if xml_parent is None or xml_parent.tag == "complexblocklist":
        return None

    # The immediate parent is a mode, jump one more level up
    if xml_parent is not None and xml_parent.tag == "mode":
        xml_parent = xml_parent.getparent()

    return xml_parent


def get_parent_pb_and_mode(xml_pbtype):
    """
    Returns a parent pb_type and mode element for the given pb_type. If there
    are no modes (implicit default mode) then the mode element returned is
    the same as the pb_type element.
    """
    assert xml_pbtype.tag in ["pb_type", "mode"], xml_pbtype.tag

    # Get immediate parent
    xml_parent = xml_pbtype.getparent()

    # We've hit the end
    if xml_parent is None or xml_parent.tag == "complexblocklist":
        return None, None

    assert xml_parent.tag in ["pb_type", "mode"], xml_parent.tag

    # pb_type parent
    if xml_pbtype.tag == "pb_type":

        if xml_parent.tag == "pb_type":
            return xml_parent, xml_parent

        elif xml_parent.tag == "mode":
            return xml_parent.getparent(), xml_parent

    elif xml_pbtype.tag == "mode":

        return xml_parent.getparent(), xml_pbtype


def get_pb_by_name(xml_parent, name):
    """
    Searches for a pb_type with the given name inside a parent pb_type.
    Returns either a child or the parent.

    The provided parent may be a mode but a pb_type is always returned.
    """
    assert xml_parent.tag in ["pb_type", "mode"], xml_parent.tag

    # Check the parent name. If this is a mode then check its parent name
    if xml_parent.tag == "mode":
        xml_parent_pb = get_parent_pb(xml_parent)
        if xml_parent_pb.attrib["name"] == name:
            return xml_parent_pb

    else:
        if xml_parent.attrib["name"] == name:
            return xml_parent

    # Check children
    for xml_pbtype in xml_parent.findall("pb_type"):
        if xml_pbtype.attrib["name"] == name:
            return xml_pbtype

    # None found
    return None


# =============================================================================


def yield_pb_children(xml_parent):
    """
    Yields all child pb_types and their indices taking into account num_pb.
    """
    for xml_child in xml_parent.findall("pb_type"):
        num_pb = int(xml_child.get("num_pb", 1))
        for i in range(num_pb):
            yield xml_child, i


# =============================================================================

INTERCONNECT_PORT_SPEC_RE = re.compile(
    r"((?P<pbtype>[A-Za-z0-9_]+)(\[(?P<indices>[0-9:]+)\])?\.)" r"(?P<port>[A-Za-z0-9_]+)(\[(?P<bits>[0-9:]+)\])?"
)


def get_pb_and_port(xml_ic, port_spec):
    """ """
    assert xml_ic.tag == "interconnect"

    # Match the port name
    match = INTERCONNECT_PORT_SPEC_RE.fullmatch(port_spec)
    assert match is not None, port_spec

    # Get the referenced pb_type
    xml_parent = xml_ic.getparent()
    xml_pbtype = get_pb_by_name(xml_parent, match.group("pbtype"))
    assert xml_pbtype is not None, port_spec

    # Find the port
    port = match.group("port")
    for xml_port in xml_pbtype:
        if xml_port.tag in ["input", "output", "clock"]:

            # Got it
            if xml_port.attrib["name"] == port:
                return xml_pbtype, xml_port
    else:
        assert False, (port_spec, xml_pbtype.attrib["name"], port)


def yield_indices(index_spec):
    """
    Given an index specification string as "<i1>:<i0>" or "<i>" yields all bits
    that it is comprised of. The function also supports cases when i0 > i1.
    """

    # None
    if index_spec is None:
        return

    # Range
    elif ":" in index_spec:
        i0, i1 = [int(i) for i in index_spec.split(":")]

        if i0 > i1:
            for i in range(i1, i0 + 1):
                yield i

        elif i0 < i1:
            for i in range(i0, i1 + 1):
                yield i

        else:
            yield i0

    # Single value
    else:
        yield int(index_spec)


def yield_pins(xml_ic, port_spec, skip_index=True):
    """
    Yields individual port pins as "<pb_type>[<pb_index].<port>[<bit>]" given
    the port specification.
    """
    assert xml_ic.tag == "interconnect"

    # Match the port name
    match = INTERCONNECT_PORT_SPEC_RE.fullmatch(port_spec)
    assert match is not None, port_spec

    # Get the referenced pb_type
    xml_parent = xml_ic.getparent()
    xml_pbtype = get_pb_by_name(xml_parent, match.group("pbtype"))
    assert xml_pbtype is not None, port_spec

    # Find the port
    port = match.group("port")
    for xml_port in xml_pbtype:
        if xml_port.tag in ["input", "output", "clock"]:
            if xml_port.attrib["name"] == port:
                width = int(xml_port.attrib["num_pins"])
                break
    else:
        assert False, (port_spec, xml_pbtype.attrib["name"], port)

    # Check if we are referencing an upstream parent
    is_parent_port = get_parent_pb(xml_ic) == xml_pbtype

    # Build a list of pb_type indices
    if not is_parent_port:
        num_pb = int(xml_pbtype.get("num_pb", 1))
        indices = list(yield_indices(match.group("indices")))
        if not indices:
            if num_pb > 1:
                indices = list(range(0, num_pb))
            else:
                indices = [None]
    else:
        indices = [None]

    # Build a list of bit indices
    bits = list(yield_indices(match.group("bits")))
    if not bits:
        if width > 1:
            bits = list(range(0, width))
        else:
            bits = [None]

    # Yield individual pin names
    for i in indices:
        for j in bits:

            name = match.group("pbtype")
            if i is not None:
                name += "[{}]".format(i)
            elif not skip_index:
                name += "[0]"

            name += "." + match.group("port")
            if j is not None:
                name += "[{}]".format(j)
            elif not skip_index:
                name += "[0]"

            yield name


# =============================================================================


def append_metadata(xml_item, meta_name, meta_data):
    """
    Appends metadata to an element of architecture
    """
    assert xml_item.tag in ["pb_type", "mode", "direct", "mux"]

    xml_meta = ET.Element("meta", {"name": meta_name})
    xml_meta.text = meta_data

    # Use existing metadata section. If not present then create a new one
    xml_metadata = xml_item.find("metadata")
    if xml_metadata is None:
        xml_metadata = ET.Element("metadata")

    # Append meta, check for conflict
    for item in xml_metadata.findall("meta"):
        assert item.attrib["name"] != xml_meta.attrib["name"]
    xml_metadata.append(xml_meta)

    # Append
    if xml_metadata.getparent() is None:
        xml_item.append(xml_metadata)
