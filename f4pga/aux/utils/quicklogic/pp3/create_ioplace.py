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
""" Convert a PCF file into a VPR io.place file. """
import argparse
import csv
import sys
import re
from collections import defaultdict

import f4pga.aux.utils.vpr_io_place as vpr_io_place
from f4pga.aux.utils.pcf import parse_simple_pcf

# =============================================================================

# Known IOB types and VPR cells that can be placed at their sites
IOB_TYPES = {
    "CLOCK": [
        "PB-CLOCK",
    ],
    "BIDIR": [
        "PB-BIDIR",
    ],
    "SDIOMUX": [
        "PB-SDIOMUX",
    ],
}

BLOCK_INSTANCE_RE = re.compile(r"^(?P<name>\S+)\[(?P<index>[0-9]+)\]$")

# =============================================================================


def main():
    parser = argparse.ArgumentParser(description="Convert a PCF file into a VPR io.place file.")
    parser.add_argument("--pcf", "-p", "-P", type=argparse.FileType("r"), required=True, help="PCF input file")
    parser.add_argument("--blif", "-b", type=argparse.FileType("r"), required=True, help="BLIF / eBLIF file")
    parser.add_argument("--map", "-m", "-M", type=argparse.FileType("r"), required=True, help="Pin map CSV file")
    parser.add_argument(
        "--output", "-o", "-O", type=argparse.FileType("w"), default=sys.stdout, help="The output io.place file"
    )
    parser.add_argument("--net", "-n", type=argparse.FileType("r"), required=True, help="top.net file")

    args = parser.parse_args()

    io_place = vpr_io_place.IoPlace()
    io_place.read_io_list_from_eblif(args.blif)
    io_place.load_block_names_from_net_file(args.net)

    # Map of pad names to VPR locations.
    pad_map = defaultdict(lambda: dict())
    pad_alias_map = defaultdict(lambda: dict())

    for pin_map_entry in csv.DictReader(args.map):
        if pin_map_entry["type"] not in IOB_TYPES:
            continue

        name = pin_map_entry["name"]
        alias = ""
        if "alias" in pin_map_entry:
            alias = pin_map_entry["alias"]

        for t in IOB_TYPES[pin_map_entry["type"]]:
            pad_map[name][t] = (
                int(pin_map_entry["x"]),
                int(pin_map_entry["y"]),
                int(pin_map_entry["z"]),
            )
            if "alias" in pin_map_entry:
                pad_alias_map[alias] = name

    used_pads = set()

    for pcf_constraint in parse_simple_pcf(args.pcf):
        # Skip non-io constraints
        if type(pcf_constraint).__name__ != "PcfIoConstraint":
            continue

        pad_name = pcf_constraint.pad
        if not io_place.is_net(pcf_constraint.net):
            print(
                'PCF constraint "{}" from line {} constraints net {} \
                        which is not in available netlist:\n{}'.format(
                    pcf_constraint.line_str, pcf_constraint.line_num, pcf_constraint.net, "\n".join(io_place.get_nets())
                ),
                file=sys.stderr,
            )
            sys.exit(1)

        if pad_name not in pad_map and pad_name not in pad_alias_map:
            print(
                'PCF constraint "{}" from line {} constraints pad {} \
                        which is not in available pad map:\n{}'.format(
                    pcf_constraint.line_str, pcf_constraint.line_num, pad_name, "\n".join(sorted(pad_map.keys()))
                ),
                file=sys.stderr,
            )
            sys.exit(1)

        # Alias is specified in pcf file so assign it to corresponding pad name
        if pad_name in pad_alias_map:
            pad_name = pad_alias_map[pad_name]

        # Catch the same pad used multiple times
        if pad_name in used_pads:
            print(
                'PCF constraint "{}" from line {} constraints pad {} \
                        which has already been constrained'.format(
                    pcf_constraint.line_str, pcf_constraint.line_num, pad_name
                ),
                file=sys.stderr,
            )
            sys.exit(1)
        used_pads.add(pad_name)

        # Get the top-level block instance, strip its index
        inst = io_place.get_top_level_block_instance_for_net(pcf_constraint.net)
        if inst is None:
            continue

        match = BLOCK_INSTANCE_RE.match(inst)
        assert match is not None, inst

        inst = match.group("name")

        # Pick correct loc for that pb_type
        locs = pad_map[pad_name]
        if inst not in locs:
            print(
                'PCF constraint "{}" from line {} constraints net {} of a block type {} \
                        to a location for block types:\n{}'.format(
                    pcf_constraint.line_str,
                    pcf_constraint.line_num,
                    pcf_constraint.net,
                    inst,
                    "\n".join(sorted(list(locs.keys()))),
                ),
                file=sys.stderr,
            )
            sys.exit(1)

        # Constraint the net (block)
        loc = locs[inst]
        io_place.constrain_net(net_name=pcf_constraint.net, loc=loc, comment=pcf_constraint.line_str)

    io_place.output_io_place(args.output)


# =============================================================================

if __name__ == "__main__":
    main()
