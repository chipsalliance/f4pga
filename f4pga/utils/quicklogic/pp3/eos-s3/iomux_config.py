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
This is an utility script that allows to generate EOS S3 IOMUX configuration
either from data in JSON format or from the given EBLIF netlist plus PCF
constraints of the FPGA design.
"""
import argparse
import csv
import json
import re
import sys

from f4pga.utils.pcf import parse_simple_pcf
from f4pga.utils.eblif import parse_blif

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

# Default configuration of the IOMUX pad
PAD_DEFAULT = {"func_sel": 0, "ctrl_sel": 0, "mode": "none", "pull": "none", "drive": 2, "slew": "slow", "schmitt": 0}

# Base address of the FBIO_SEL registers
FBIOSEL_BASE = 0x40004D80

# Base address of the IOMUX registers
IOMUX_BASE = 0x40004C00

# =============================================================================


def generate_iomux_register_content(config):
    """
    Generates a content of IOMUX registers according to the given config.
    """
    iomux_regs = {}

    # Generate content of the IOMUX_PAD_O_CTRL register for each pad
    for pad, pad_cfg in config["pads"].items():
        pad = int(pad)
        reg = 0

        # Patch default settings with settings read from the config file
        pad_cfg = dict(PAD_DEFAULT, **pad_cfg)

        func_sel = pad_cfg["func_sel"]
        assert func_sel in [0, 1], func_sel
        reg |= func_sel

        ctrl_sel = pad_cfg["ctrl_sel"]
        assert ctrl_sel in ["A0", "others", "fabric"], ctrl_sel
        if ctrl_sel == "A0":
            reg |= 0 << 3
        elif ctrl_sel == "others":
            reg |= 1 << 3
        elif ctrl_sel == "fabric":
            reg |= 2 << 3

        mode = pad_cfg["mode"]
        assert mode in ["none", "input", "output", "inout"], mode
        if mode == "none":
            oen = 0
            ren = 0
        elif mode == "input":
            oen = 0
            ren = 1
        elif mode == "output":
            oen = 1
            ren = 0
        elif mode == "inout":
            oen = 1
            ren = 1
        reg |= (oen << 5) | (ren << 11)

        pull = pad_cfg["pull"]
        assert pull in ["none", "up", "down", "keeper"], pull
        if pull == "none":
            reg |= 0 << 6
        elif pull == "up":
            reg |= 1 << 6
        elif pull == "down":
            reg |= 2 << 6
        elif pull == "keeper":
            reg |= 3 << 6

        drive = pad_cfg["drive"]
        assert drive in [2, 4, 8, 12], drive
        if drive == 2:
            reg |= 0 << 8
        elif drive == 4:
            reg |= 1 << 8
        elif drive == 8:
            reg |= 2 << 8
        elif drive == 12:
            reg |= 3 << 8

        slew = pad_cfg["slew"]
        assert slew in ["slow", "fast"], slew
        if slew == "slow":
            reg |= 0 << 10
        elif slew == "fast":
            reg |= 1 << 10

        schmitt = pad_cfg["schmitt"]
        assert schmitt in [0, 1], schmitt
        reg |= schmitt << 12

        # Register address
        adr = IOMUX_BASE + pad * 4

        # Store the value
        iomux_regs[adr] = reg

    # Generate content of FBIO_SEL_1 and FBIO_SEL_2
    fbio_sel = {0: 0, 1: 0}
    for pad in config["pads"].keys():
        r = int(pad) // 32
        b = int(pad) % 32
        fbio_sel[r] |= 1 << b

    iomux_regs[FBIOSEL_BASE + 0x0] = fbio_sel[0]
    iomux_regs[FBIOSEL_BASE + 0x4] = fbio_sel[1]

    return iomux_regs


# =============================================================================


def main():
    """
    Main
    """

    # Parse arguments
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument("--json", default=None, type=str, help="Read IOMUX configuration from the given JSON file")

    parser.add_argument("--eblif", default=None, type=str, help="EBLIF netlist file of a design")

    parser.add_argument("--pcf", default=None, type=str, help="PCF constraints file for a design")
    parser.add_argument("--map", "-m", "-M", type=argparse.FileType("r"), required=True, help="Pin map CSV file")

    parser.add_argument(
        "--output-format", default=None, type=str, help="Output format of IOMUX commands (openocd/jlink)"
    )

    args = parser.parse_args()

    # Read the requested configurtion from a JSON file
    if args.json is not None:

        if args.pcf is not None or args.eblif is not None:
            print("Use either '--json' or '--pcf' + '--eblif' options!")
            exit(-1)

        with open(args.json, "r") as fp:
            config = json.load(fp)

    # Generate the config according to the EBLIF netlist and PCF constraints.
    else:

        if args.json is not None or (args.eblif is None or args.pcf is None):
            print("Use either '--json' or '--pcf' + '--eblif' options!")
            exit(-1)

        pad_map = {}
        pad_alias_map = {}

        for pin_map_entry in csv.DictReader(args.map):

            if pin_map_entry["type"] not in IOB_TYPES:
                continue

            name = pin_map_entry["name"]
            alias = ""
            if "alias" in pin_map_entry:
                alias = pin_map_entry["alias"]
                pad_alias_map[alias] = name
                pad_map[name] = alias
            else:
                pad_map[name] = name

        # Read and parse PCF
        with open(args.pcf, "r") as fp:
            pcf = list(parse_simple_pcf(fp))

        # Read and parse BLIF/EBLIF
        with open(args.eblif, "r") as fp:
            eblif = parse_blif(fp)

        # Build the config
        config = {"pads": {}}

        eblif_inputs = eblif["inputs"]["args"]
        eblif_outputs = eblif["outputs"]["args"]

        for constraint in pcf:

            pad_name = constraint.pad

            if pad_name not in pad_map and pad_name not in pad_alias_map:
                print(
                    "PCF constraint '{}' from line {} constraints pad {} "
                    "which is not in available pad map:\n{}".format(
                        constraint.line_str, constraint.line_num, pad_name, "\n".join(sorted(pad_map.keys()))
                    ),
                    file=sys.stderr,
                )
                sys.exit(1)

            # get pad alias to get IO pad count
            pad_alias = ""
            if pad_name in pad_map:
                pad_alias = pad_map[pad_name]

            # Alias is specified in pcf file so assign it to corresponding pad name
            if pad_name in pad_alias_map:
                pad_alias = pad_name

            pad = None

            match = re.match(r"^IO_([0-9]+)$", pad_alias)
            if match is not None:
                pad = int(match.group(1))

            # Pad not found or out of range
            if pad is None or pad < 0 or pad >= 46:
                continue

            # Detect inouts:
            def inout_name(name, suffix):
                expr = r"(?P<name>.*)(?P<index>\[[0-9]+\])$"
                match = re.fullmatch(expr, name)
                if match is not None:
                    return match.group("name") + suffix + match.group("index")
                return name + suffix

            is_inout_in = inout_name(constraint.net, "_$inp") in eblif_inputs
            is_inout_out = inout_name(constraint.net, "_$out") in eblif_outputs

            if is_inout_in and is_inout_out:
                pad_config = {
                    "ctrl_sel": "fabric",
                    "mode": "inout",
                }

            elif constraint.net in eblif_inputs:
                pad_config = {
                    "ctrl_sel": "fabric",
                    "mode": "input",
                }

            # Configure as output
            elif constraint.net in eblif_outputs:
                pad_config = {
                    "ctrl_sel": "fabric",
                    "mode": "output",
                }

            else:
                assert False, (constraint.net, constraint.pad)

            config["pads"][str(pad)] = pad_config

    # Convert the config to IOMUX register content
    iomux_regs = generate_iomux_register_content(config)

    if args.output_format == "openocd":
        # Output openOCD process
        for adr in sorted(iomux_regs.keys()):
            print("    mww 0x{:08x} 0x{:08x}".format(adr, iomux_regs[adr]))
    elif args.output_format == "jlink":
        # Output JLink commands
        for adr in sorted(iomux_regs.keys()):
            print("w4 0x{:08x} 0x{:08x}".format(adr, iomux_regs[adr]))
    elif args.output_format == "binary":
        # Output binary file: <REGADDR 4B><REGVAL 4B>...
        for adr in sorted(iomux_regs.keys()):
            # first the address
            addr_bytes = int(adr).to_bytes(4, byteorder="little")
            # output the address as raw bytes, bypass the print(), LE, 4B
            sys.stdout.buffer.write(addr_bytes)
            # second the value
            val_bytes = int(iomux_regs[adr]).to_bytes(4, byteorder="little")
            # output the value as raw bytes, bypass the print(), LE, 4B
            sys.stdout.buffer.write(val_bytes)
    else:
        print("Use either 'openocd' or 'jlink' or 'binary' output format!")
        exit(-1)


# =============================================================================

if __name__ == "__main__":
    main()
