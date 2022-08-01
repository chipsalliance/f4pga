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

from f4pga.common import *
from f4pga.module import Module, ModuleContext


def analysis_merged_post_implementation_file(ctx: ModuleContext):
    return str(Path(ctx.takes.eblif).with_suffix('')) + '_merged_post_implementation.v'


def analysis_post_implementation_file(ctx: ModuleContext):
    return str(Path(ctx.takes.eblif).with_suffix('')) + '_post_synthesis.v'


class analysisModule(Module):
    def map_io(self, ctx: ModuleContext):
        return {
            'merged_post_implementation_v': analysis_merged_post_implementation_file(ctx),
            'post_implementation_v': analysis_post_implementation_file(ctx)
        }

    def execute(self, ctx: ModuleContext):
        build_dir = str(Path(ctx.takes.eblif).parent)

        vpr_options = []
        if ctx.values.vpr_options:
            vpr_options = options_dict_to_list(ctx.values.vpr_options)

        yield 'Analysis with VPR...'
        vpr(
            'analysis',
            VprArgs(
                ctx.share,
                ctx.takes.eblif,
                ctx.values,
                sdc_file=ctx.takes.sdc
            ),
            cwd=build_dir
        )

        if ctx.is_output_explicit('merged_post_implementation_v'):
            sh_mv(analysis_merged_post_implementation_file(ctx), ctx.outputs.merged_post_implementation_v)

        if ctx.is_output_explicit('post_implementation_v'):
            sh_mv(analysis_post_implementation_file(ctx), ctx.outputs.post_implementation_v)

        yield 'Saving log...'
        save_vpr_log('analysis.log', build_dir=build_dir)

    def __init__(self, _):
        self.name = 'analysis'
        self.no_of_phases = 2
        self.takes = [
            'eblif',
            'route',
            'sdc?'
        ]
        self.produces = [
            'merged_post_implementation_v',
            'post_implementation_v',
            'analysis_log'
        ]
        self.values = [
            'device',
            'vpr_options?'
        ] + vpr_specific_values()

ModuleClass = analysisModule
