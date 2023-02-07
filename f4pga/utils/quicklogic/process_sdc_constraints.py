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
This script processes an SDC constraint file and replaces all references to
pin names in place of net names with actual net names that are mapped to those
pins. Pin-to-net mapping is read from a PCF constraint file.

Note that this script does not check whether the net names in the input PCF
file are actually present in a design and whether the pin names are valid.
"""

import argparse
import re
import csv

from f4pga.utils.pcf import parse_simple_pcf, PcfIoConstraint
from f4pga.utils.eblif import parse_blif


RE_INDICES = re.compile(r"(?P<name>\S+)\[(?P<i0>[0-9]+):(?P<i1>[0-9]+)\]")


def collect_eblif_nets(eblif):
    """
    Collects all net names that are present in the given parsed BLIF/EBLIF
    netlist. Returns a set of net names
    """
    nets = set()

    # First add all input and output nets
    for key in ["inputs", "outputs", "clocks"]:
        nets |= set(eblif.get(key, []))

    # Look for cell-to-cell connections
    for cell in eblif.get("subckt", []):
        for conn in cell["args"][1:]:
            port, net = conn.split("=")
            nets.add(net)

    for cell in eblif.get("names", []):
        nets |= set(cell["args"])

    for cell in eblif.get("latch", []):
        args = cell["args"]
        assert len(args) >= 2
        nets.add(args[0])
        nets.add(args[1])

        if len(args) >= 4:
            nets.add(args[3])

    return nets


def expand_indices(items):
    """
    Expands index ranges for each item in the given iterable. For example
    converts a single item like: "pin[1:0]" into two "pin[1]" and "pin[0]".
    """
    new_items = []

    # Process each item
    for item in items:
        # Match using regex. If there is no match then pass the item through
        match = RE_INDICES.fullmatch(item)
        if not match:
            new_items.append(item)
            continue

        name = match.group("name")
        i0 = int(match.group("i0"))
        i1 = int(match.group("i1"))

        # Generate individual indices
        if i0 == i1:
            indices = [i0]
        elif i0 < i1:
            indices = [i for i in range(i0, i1 + 1)]
        elif i0 > i1:
            indices = [i for i in range(i1, i0 + 1)]

        # Generate names
        for i in indices:
            new_items.append("{}[{}]".format(name, i))

    return new_items


def process_get_ports(match, pad_to_net, valid_pins=None, valid_nets=None):
    """
    Used as a callback in re.sub(). Responsible for substition of net names
    for pin names.

    When the valid_pin list is provided the function checks if a name specified
    in SDC refers to any of them. If it is so and the pin name is not present
    in the PCF mapping an error is thrown - it is not possible to map the pin
    to a net.

    When no valid_pin list is known then there is no possibility to check if
    a given name refers to a pin or net. Hence if it is present in the PCF
    mapping it is considered a pin name and gets remapped to a net accordingly.
    Otherwise it is just passed through.

    Lastly, if the valid_nets list is provided the function checks if the
    final net name is valid and throws an error if it is not.
    """

    # Strip any spurious whitespace chars
    arg = match.group("arg").strip()

    # A helper mapping func.
    def map_pad_to_net(pad):
        # Unescape square brackets
        pad = pad.replace("\\[", "[")
        pad = pad.replace("\\]", "]")

        # If we have a valid pins list and the pad is in the map then re-map it
        if valid_pins and pad in valid_pins:
            assert pad in pad_to_net, "The pin '{}' is not associated with any net in PCF".format(pad)
            net = pad_to_net[pad].net

        # If we don't have a valid pins list then just look up in the PCF
        # mapping.
        elif not valid_pins and pad in pad_to_net:
            net = pad_to_net[pad].net

        # Otherwise it looks like its a direct reference to a net so pass it
        # through.
        else:
            net = pad

        # If we have a valit net list then validate the net name
        if valid_nets:
            assert net in valid_nets, "The net '{}' is not present in the netlist".format(net)

        # Escape square brackets
        net = net.replace("[", "\\[")
        net = net.replace("]", "\\]")
        return net

    # We have a list of ports, map each of them individually
    if arg[0] == "{" and arg[-1] == "}":
        arg = arg[1:-1].split()
        nets = ", ".join([map_pad_to_net(p) for p in arg])
        new_arg = "{{{}}}".format(nets)

    # We have a single port, map it directly
    else:
        new_arg = map_pad_to_net(arg)

    # Format the new statement
    return "[get_ports {}]".format(new_arg)


# =============================================================================


def main():
    # Parse arguments
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument("--sdc-in", type=str, required=True, help="Input SDC file")
    parser.add_argument("--pcf", type=str, required=True, help="Input PCF file")
    parser.add_argument("--sdc-out", type=str, required=True, help="Output SDC file")
    parser.add_argument("--eblif", type=str, default=None, help="Input EBLIF netlist file")
    parser.add_argument("--pin-map", type=str, default=None, help="Input CSV pin map file")

    args = parser.parse_args()

    # Read the input PCF file
    with open(args.pcf, "r") as fp:
        pcf_constraints = list(parse_simple_pcf(fp))

    # Build a pad-to-net map
    pad_to_net = {}
    for constr in pcf_constraints:
        if isinstance(constr, PcfIoConstraint):
            assert constr.pad not in pad_to_net, "Multiple nets constrained to pin '{}'".format(constr.pad)
            pad_to_net[constr.pad] = constr

    # Read the input SDC file
    with open(args.sdc_in, "r") as fp:
        sdc = fp.read()

    # Read the input EBLIF file, extract all valid net names from it
    valid_nets = None
    if args.eblif is not None:
        with open(args.eblif, "r") as fp:
            eblif = parse_blif(fp)
        valid_nets = collect_eblif_nets(eblif)

    # Reat the input pinmap CSV file, extract valid pin names from it
    valid_pins = None
    if args.pin_map is not None:
        with open(args.pin_map, "r") as fp:
            reader = csv.DictReader(fp)
            csv_data = list(reader)
        valid_pins = [line["mapped_pin"] for line in csv_data]
        valid_pins = set(expand_indices(valid_pins))

    # Process the SDC
    def sub_cb(match):
        return process_get_ports(match, pad_to_net, valid_pins, valid_nets)

    sdc_lines = sdc.splitlines()
    for i in range(len(sdc_lines)):
        if not sdc_lines[i].strip().startswith("#"):
            sdc_lines[i] = re.sub(r"\[\s*get_ports\s+(?P<arg>.*)\]", sub_cb, sdc_lines[i])

    # Write the output SDC file
    sdc = "\n".join(sdc_lines) + "\n"
    with open(args.sdc_out, "w") as fp:
        fp.write(sdc)


# =============================================================================

if __name__ == "__main__":
    main()
