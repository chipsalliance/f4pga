#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright (C) 2019-2022 F4PGA Authors
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
Convert a PCF file into a VPR io.place file.
"""


from argparse import ArgumentParser, FileType
from pathlib import Path
from csv import DictReader as csv_DictReader
from sys import stdout, stderr, exit as sys_exit
from json import dump as json_dump, load as json_load

from f4pga.aux.utils.vpr_io_place import IoPlace
from f4pga.aux.utils.pcf import parse_simple_pcf


def p_main(blif, map, net, pcf=None, output=stdout, iostandard_defs_file=None, iostandard="LVCMOS33", drive=12):
    io_place = IoPlace()
    io_place.read_io_list_from_eblif(blif)
    io_place.load_block_names_from_net_file(net)

    # Map of pad names to VPR locations.
    pad_map = {}

    for pin_map_entry in csv_DictReader(map):
        pad_map[pin_map_entry["name"]] = (
            (
                int(pin_map_entry["x"]),
                int(pin_map_entry["y"]),
                int(pin_map_entry["z"]),
            ),
            pin_map_entry["is_output"],
            pin_map_entry["iob"],
            pin_map_entry["real_io_assoc"],
        )

    iostandard_defs = {}

    # Load iostandard constraints. This is a temporary workaround that allows
    # to pass them into fasm2bels. As soon as there is support for XDC this
    # will not be needed anymore.
    # If there is a JSON file with the same name as the PCF file then it is
    # loaded and used as iostandard constraint source NOT for the design but
    # to be used in fasm2bels.
    iostandard_constraints = {}

    if pcf is not None:
        fname = Path(pcf.name.replace(".pcf", ".json"))
        if fname.is_file():
            with fname.open("r") as fp:
                iostandard_constraints = json_load(fp)
    net_to_pad = io_place.net_to_pad
    if pcf is not None:
        net_to_pad |= set((constr.net, constr.pad) for constr in parse_simple_pcf(pcf))
    # Check for conflicting pad constraints
    net_to_pad_map = dict()
    for net, pad in net_to_pad:
        if net not in net_to_pad_map:
            net_to_pad_map[net] = pad
        elif pad != net_to_pad_map[net]:
            print(
                f"ERROR: Conflicting pad constraints for net {net}:\n{pad}\n{net_to_pad_map[net]}",
                file=stderr,
            )
            sys_exit(1)

    # Constrain nets
    for net, pad in net_to_pad:
        if not io_place.is_net(net):
            nets = "\n".join(io_place.get_nets())
            print(
                f"ERROR: Constrained net {net} is not in available netlist:\n{nets}",
                file=stderr,
            )
            sys_exit(1)

        if pad not in pad_map:
            pads = "\n".join(sorted(pad_map.keys()))
            print(
                f"ERROR: Constrained pad {pad} is not in available pad map:\n{pads}",
                file=stderr,
            )
            sys_exit(1)

        loc, is_output, iob, real_io_assoc = pad_map[pad]

        io_place.constrain_net(net_name=net, loc=loc, comment="set_property LOC {} [get_ports {{{}}}]".format(pad, net))
        if real_io_assoc == "True":
            iostandard_defs[iob] = (
                iostandard_constraints[pad]
                if pad in iostandard_constraints
                else ({"DRIVE": drive, "IOSTANDARD": iostandard} if is_output else {"IOSTANDARD": iostandard})
            )

    io_place.output_io_place(output)

    # Write iostandard definitions
    if iostandard_defs_file is not None:
        with Path(iostandard_defs_file).open("w") as f:
            json_dump(iostandard_defs, f, indent=2)


def main(
    blif,
    map,
    net,
    pcf=None,
    output=None,
    iostandard_defs_file=None,
    iostandard="LVCMOS33",
    drive=12,
):
    p_main(
        blif=Path(blif).open("r"),
        map=Path(map).open("r"),
        net=Path(net).open("r"),
        pcf=None if pcf is None else pcf,
        output=stdout if output is None else Path(output).open("w"),
        iostandard_defs_file=iostandard_defs_file,
        iostandard=iostandard,
        drive=drive,
    )


if __name__ == "__main__":
    parser = ArgumentParser(description="Convert a PCF file into a VPR io.place file.")
    parser.add_argument("--pcf", "-p", "-P", type=FileType("r"), required=False, help="PCF input file")
    parser.add_argument("--blif", "-b", type=FileType("r"), required=True, help="BLIF / eBLIF file")
    parser.add_argument("--map", "-m", "-M", type=FileType("r"), required=True, help="Pin map CSV file")
    parser.add_argument("--output", "-o", "-O", type=FileType("w"), default=stdout, help="The output io.place file")
    parser.add_argument("--iostandard_defs", help="(optional) Output IOSTANDARD def file")
    parser.add_argument(
        "--iostandard",
        default="LVCMOS33",
        help="Default IOSTANDARD to use for pins",
    )
    parser.add_argument(
        "--drive",
        type=int,
        default=12,
        help="Default drive to use for pins",
    )
    parser.add_argument("--net", "-n", type=FileType("r"), required=True, help="top.net file")

    args = parser.parse_args()

    p_main(
        blif=args.blif,
        map=args.map,
        net=args.net,
        pcf=args.pcf,
        output=args.output,
        iostandard_defs_file=args.iostandard_defs,
        iostandard=args.iostandard,
        drive=args.drive,
    )
