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

from f4pga.common import vpr_specific_values, VprArgs, get_verbosity_level, sub
from f4pga.module import Module, ModuleContext


class FasmModule(Module):

    def map_io(self, ctx: ModuleContext):
        build_dir = str(Path(ctx.takes.eblif).parent)
        return {
            'fasm': f'{(Path(build_dir)/ctx.values.top)!s}.fasm'
        }

    def execute(self, ctx: ModuleContext):
        build_dir = str(Path(ctx.takes.eblif).parent)

        vprargs = VprArgs(ctx.share, ctx.takes.eblif, ctx.values)

        optional = []
        if ctx.values.pnr_corner is not None:
            optional += ['--pnr_corner', ctx.values.pnr_corner]
        if ctx.takes.sdc:
            optional += ['--sdc', ctx.takes.sdc]

        s = [
            'genfasm',
            vprargs.arch_def,
            str(Path(ctx.takes.eblif).resolve()),
            '--device',
            vprargs.device_name,
            '--read_rr_graph',
            vprargs.rr_graph
        ] + vprargs.optional

        if get_verbosity_level() >= 2:
            yield 'Generating FASM...\n           ' + ' '.join(s)
        else:
            yield 'Generating FASM...'

        sub(*s, cwd=build_dir)

        default_fasm_output_name = f'{(Path(build_dir)/ctx.values.top)!s}.fasm'
        if default_fasm_output_name != ctx.outputs.fasm:
            sh_mv(default_fasm_output_name, ctx.outputs.fasm)

        if ctx.takes.fasm_extra:
            yield 'Appending extra FASM...'
            with \
                open(ctx.outputs.fasm, 'r') as fasm_file, \
                open(ctx.takes.fasm_extra, 'r') as fasm_extra_file, \
                open(ctx.outputs.fasm, 'w') as wfptr:
                wfptr.write(f"{fasm_file.read()}\n{fasm_extra_file.read()}")
        else:
            yield 'No extra FASM to append'

    def __init__(self, _):
        self.name = 'fasm'
        self.no_of_phases = 2
        self.takes = [
            'eblif',
            'net',
            'place',
            'route',
            'fasm_extra?',
            'sdc?'
        ]
        self.produces = [ 'fasm' ]
        self.values = [
            'device',
            'top',
            'pnr_corner?'
        ] + vpr_specific_values()
        self.prod_meta = {
            'fasm': 'FPGA assembly file'
        }

ModuleClass = FasmModule
