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

from f4pga.flows.common import vpr_specific_values, vpr as common_vpr, VprArgs
from f4pga.flows.module import Module, ModuleContext


class analysisModule(Module):
    def map_io(self, ctx: ModuleContext):
        return {
            "merged_post_implementation_v": p_analysis_merged_post_implementation_file(ctx),
            "post_implementation_v": p_analysis_post_implementation_file(ctx),
        }

    def execute(self, ctx: ModuleContext):
        build_dir = Path(ctx.takes.eblif).parent

        yield "Analysis with VPR..."
        common_vpr(
            "analysis",
            VprArgs(
                share=ctx.share,
                eblif=ctx.takes.eblif,
                arch_def=ctx.values.arch_def,
                lookahead=ctx.values.rr_graph_lookahead_bin,
                rr_graph=ctx.values.rr_graph_real_bin,
                place_delay=ctx.values.vpr_place_delay,
                device_name=ctx.values.vpr_grid_layout_name,
                vpr_options=ctx.values.vpr_options if ctx.values.vpr_options else {},
                sdc_file=ctx.takes.sdc,
            ),
            cwd=build_dir,
        )

        if ctx.is_output_explicit("merged_post_implementation_v"):
            Path(p_analysis_merged_post_implementation_file(ctx)).rename(ctx.outputs.merged_post_implementation_v)

        if ctx.is_output_explicit("post_implementation_v"):
            Path(p_analysis_post_implementation_file(ctx)).rename(ctx.outputs.post_implementation_v)

        yield "Saving log..."
        save_vpr_log("analysis.log", build_dir=build_dir)

    def __init__(self, _):
        self.name = "analysis"
        self.no_of_phases = 2
        self.takes = ["eblif", "route", "sdc?"]
        self.produces = ["merged_post_implementation_v", "post_implementation_v", "analysis_log"]
        self.values = ["device", "vpr_options?"] + vpr_specific_values


ModuleClass = analysisModule


def p_analysis_merged_post_implementation_file(ctx: ModuleContext):
    return str(Path(ctx.takes.eblif).with_suffix("")) + "_merged_post_implementation.v"


def p_analysis_post_implementation_file(ctx: ModuleContext):
    return str(Path(ctx.takes.eblif).with_suffix("")) + "_post_synthesis.v"
