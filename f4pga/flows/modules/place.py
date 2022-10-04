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
from re import match as re_match

from f4pga.flows.tools.vpr import vpr_specific_values, vpr, VprArgs, save_vpr_log
from f4pga.flows.module import Module, ModuleContext


def p_default_output_name(eblif):
    return Path(eblif).with_suffix(".place")


class PlaceModule(Module):
    def map_io(self, ctx: ModuleContext):
        return {"place": str(p_default_output_name(ctx.takes.eblif))}

    def execute(self, ctx: ModuleContext):
        build_dir = ctx.takes.build_dir

        vpr_options = ctx.values.vpr_options if ctx.values.vpr_options else {}
        if ctx.takes.place_constraints:
            vpr_options.update({"fix_clusters": ctx.takes.place_constraints})

        yield "Running VPR..."
        vpr(
            "place",
            VprArgs(
                share=ctx.share,
                eblif=ctx.takes.eblif,
                arch_def=ctx.values.arch_def,
                lookahead=ctx.values.rr_graph_lookahead_bin,
                rr_graph=ctx.values.rr_graph_real_bin,
                place_delay=ctx.values.vpr_place_delay,
                device_name=ctx.values.vpr_grid_layout_name,
                vpr_options=vpr_options,
                sdc_file=ctx.takes.sdc,
            ),
            cwd=build_dir,
        )

        # VPR names output on its own. If user requested another name, the
        # output file should be moved.
        # TODO: This extends the set of names that would cause collisions.
        # As for now (22-07-2021), no collision detection is being done, but
        # when the problem gets tackled, we should keep in mind that VPR-based
        # modules may produce some temporary files with names that differ from
        # the ones in flow configuration.
        if ctx.is_output_explicit("place"):
            p_default_output_name(ctx.takes.eblif).rename(ctx.outputs.place)

        yield "Saving log..."
        save_vpr_log("place.log", build_dir=build_dir)

    def __init__(self, _):
        self.name = "place"
        self.no_of_phases = 2
        self.takes = ["build_dir", "eblif", "sdc?", "place_constraints?", "io_place?"]
        self.produces = ["place"]
        self.values = ["device", "vpr_options?"] + vpr_specific_values


ModuleClass = PlaceModule
