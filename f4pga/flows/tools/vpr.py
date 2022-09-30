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


from pathlib import Path
from shutil import move as sh_mv

from f4pga.flows.common import sub as common_sub, options_dict_to_list


class VprArgs:
    """
    Represents argument list for VPR (Versatile Place and Route).
    """

    arch_dir: str
    arch_def: str
    lookahead: str
    rr_graph: str
    place_delay: str
    device_name: str
    eblif: str
    optional: list

    def __init__(
        self,
        share: str,
        eblif,
        arch_def,
        lookahead,
        rr_graph,
        place_delay,
        device_name,
        vpr_options={},
        sdc_file: "str | None" = None,
    ):
        self.arch_dir = str(Path(share) / "arch")
        self.arch_def = arch_def
        self.lookahead = lookahead
        self.rr_graph = rr_graph
        self.place_delay = place_delay
        self.device_name = device_name
        self.eblif = str(Path(eblif).resolve())
        self.optional = options_dict_to_list(vpr_options)
        if sdc_file is not None:
            self.optional += ["--sdc_file", sdc_file]


def vpr(mode: str, vprargs: VprArgs, cwd=None):
    """
    Execute `vpr`.
    """
    return common_sub(
        *(
            [
                "vpr",
                vprargs.arch_def,
                vprargs.eblif,
                "--device",
                vprargs.device_name,
                "--read_rr_graph",
                vprargs.rr_graph,
                "--read_router_lookahead",
                vprargs.lookahead,
                "--read_placement_delay_lookup",
                vprargs.place_delay,
            ]
            + ([f"--{mode}"] if mode in ["pack", "place", "route", "analysis"] else [])
            + vprargs.optional
        ),
        cwd=cwd,
        print_stdout_on_fail=True,
    )


vpr_specific_values = [
    "arch_def",
    "rr_graph_lookahead_bin",
    "rr_graph_real_bin",
    "vpr_place_delay",
    "vpr_grid_layout_name",
    "vpr_options?",
]


def save_vpr_log(filename, build_dir=""):
    """
    Save VPR logic (moves the default output file into a desired path).
    """
    sh_mv(str(Path(build_dir) / "vpr_stdout.log"), filename)
