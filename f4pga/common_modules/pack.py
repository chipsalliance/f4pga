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
from os import remove as os_remove
from shutil import move as sh_mv

from f4pga.common import *
from f4pga.module import Module, ModuleContext


DEFAULT_TIMING_RPT = 'pre_pack.report_timing.setup.rpt'
DEFAULT_UTIL_RPT = 'packing_pin_util.rpt'


class PackModule(Module):
    def map_io(self, ctx: ModuleContext):
        epath = Path(ctx.takes.eblif)
        build_dir = epath.parent
        return {
            'net': str(epath.with_suffix('.net')),
            'util_rpt': str(build_dir / DEFAULT_UTIL_RPT),
            'timing_rpt': str(build_dir / DEFAULT_TIMING_RPT)
        }

    def execute(self, ctx: ModuleContext):
        noisy_warnings(ctx.values.device)
        build_dir = Path(ctx.outputs.net).parent

        yield 'Packing with VPR...'
        vpr(
            'pack',
            VprArgs(
                ctx.share,
                ctx.takes.eblif,
                ctx.values,
                sdc_file=ctx.takes.sdc
            ),
            cwd=str(build_dir)
        )

        og_log = str(build_dir / 'vpr_stdout.log')

        yield 'Moving/deleting files...'
        if ctx.outputs.pack_log:
            sh_mv(og_log, ctx.outputs.pack_log)
        else:
            os_remove(og_log)

        if ctx.outputs.timing_rpt:
            sh_mv(str(build_dir / DEFAULT_TIMING_RPT), ctx.outputs.timing_rpt)

        if ctx.outputs.util_rpt:
            sh_mv(str(build_dir / DEFAULT_UTIL_RPT), ctx.outputs.util_rpt)

    def __init__(self, _):
        self.name = 'pack'
        self.no_of_phases = 2
        self.takes = [
            'eblif',
            'sdc?'
        ]
        self.produces = [
            'net',
            'util_rpt',
            'timing_rpt',
            'pack_log!'
        ]
        self.values = [
            'device',
        ] + vpr_specific_values()

ModuleClass = PackModule
