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
import argparse
import sys
import csv

import f4pga.utils.eblif as eblif

# =============================================================================


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def get_cell_connection(cell, pin):
    """
    Returns the name of the net connected to the given cell pin. Returns None
    if unconnected
    """

    # Only for subckt
    assert cell["type"] == "subckt"

    # Find the connection and return it
    for i in range(1, len(cell["args"])):
        p, net = cell["args"][i].split("=")
        if p == pin:
            return net

    # Not found
    return None


# =============================================================================


def main():
    parser = argparse.ArgumentParser(description="Creates placement constraints other than IOs")

    parser.add_argument(
        "--input", "-i", "-I", type=argparse.FileType("r"), default=sys.stdin, help="The input constraints place file."
    )
    parser.add_argument(
        "--output",
        "-o",
        "-O",
        type=argparse.FileType("w"),
        default=sys.stdout,
        help="The output constraints place file.",
    )
    parser.add_argument("--map", type=argparse.FileType("r"), required=True, help="Clock pinmap CSV file")
    parser.add_argument("--blif", "-b", type=argparse.FileType("r"), required=True, help="BLIF / eBLIF file.")

    args = parser.parse_args()

    # Load clock map
    clock_to_gmux = {}
    for row in csv.DictReader(args.map):
        name = row["name"]
        src_loc = (
            int(row["src.x"]),
            int(row["src.y"]),
            int(row["src.z"]),
        )
        dst_loc = (
            int(row["dst.x"]),
            int(row["dst.y"]),
            int(row["dst.z"]),
        )

        clock_to_gmux[src_loc] = (dst_loc, name)

    # Load EBLIF
    eblif_data = eblif.parse_blif(args.blif)

    # Process the IO constraints file. Pass the constraints unchanged, store
    # them.
    io_constraints = {}

    for line in args.input:
        # Strip, skip comments
        line = line.strip()
        if line.startswith("#"):
            continue

        args.output.write(line + "\n")

        # Get block and its location
        block, x, y, z = line.split()[0:4]
        io_constraints[block] = (
            int(x),
            int(y),
            int(z),
        )

    # Analyze the BLIF netlist. Find clock inputs that go through CLOCK IOB to
    # GMUXes.
    clock_connections = []

    IOB_CELL = {"type": "CLOCK_CELL", "ipin": "I_PAD", "opin": "O_CLK"}
    BUF_CELL = {"type": "GMUX_IP", "ipin": "IP", "opin": "IZ"}

    for inp_net in eblif_data["inputs"]["args"]:
        # This one is not constrained, skip it
        if inp_net not in io_constraints:
            continue

        # Search for a CLOCK cell connected to that net
        for cell in eblif_data["subckt"]:
            if cell["type"] == "subckt" and cell["args"][0] == IOB_CELL["type"]:
                net = get_cell_connection(cell, IOB_CELL["ipin"])
                if net == inp_net:
                    iob_cell = cell
                    break
        else:
            continue

        # Get the output net of the CLOCK cell
        con_net = get_cell_connection(iob_cell, IOB_CELL["opin"])
        if not con_net:
            continue

        # Search for a GMUX connected to the CLOCK cell
        for cell in eblif_data["subckt"]:
            if cell["type"] == "subckt" and cell["args"][0] == BUF_CELL["type"]:
                net = get_cell_connection(cell, BUF_CELL["ipin"])
                if net == con_net:
                    buf_cell = cell
                    break
        else:
            continue

        # Get the output net of the GMUX
        clk_net = get_cell_connection(buf_cell, BUF_CELL["opin"])
        if not clk_net:
            continue

        # Store data
        clock_connections.append((inp_net, iob_cell, con_net, buf_cell, clk_net))

    # Emit constraints for GCLK cells
    for inp_net, iob_cell, con_net, buf_cell, clk_net in clock_connections:
        src_loc = io_constraints[inp_net]
        if src_loc not in clock_to_gmux:
            eprint("ERROR: No GMUX location for input CLOCK pad for net '{}' at {}".format(inp_net, src_loc))
            continue

        dst_loc, name = clock_to_gmux[src_loc]

        # FIXME: Silently assuming here that VPR will name the GMUX block as
        # the GMUX cell in EBLIF. In order to fix that there will be a need
        # to read & parse the packed netlist file.
        line = "{} {} {} {} # {}\n".format(buf_cell["cname"][0], *dst_loc, name)
        args.output.write(line)


# =============================================================================

if __name__ == "__main__":
    main()
