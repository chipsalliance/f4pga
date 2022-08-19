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

from os import environ
from pathlib import Path

from f4pga.flows.common import decompose_depname, get_verbosity_level, sub as common_sub
from f4pga.flows.module import Module, ModuleContext
from f4pga.wrappers.tcl import get_script_path as get_tcl_wrapper_path


def yosys_setup_tcl_env(tcl_env_def):
    """
    Setup environmental variables for YOSYS TCL scripts.
    """
    return {
        key: (' '.join(val) if type(val) is list else val)
        for key, val in tcl_env_def.items()
        if val is not None
    }


def yosys_synth(tcl, tcl_env, verilog_files=[], read_verilog_args=None, log=None):
    tcl = f'tcl {tcl}'
    # Use append read_verilog commands to the scripts for more sophisticated
    # input if arguments are specified. Omit direct input throught `yosys` command.
    if read_verilog_args:
        args_str = ' '.join(read_verilog_args)
        for verilog in verilog_files:
            tcl = f'read_verilog {args_str} {verilog}; {tcl}'
        verilog_files = []

    # Set up environment for TCL weirdness
    env = environ.copy()
    env.update(tcl_env)
    # Execute YOSYS command
    return common_sub(*(['yosys', '-p', tcl] + (['-l', log] if log else []) + verilog_files), env=env)


def yosys_conv(tcl, tcl_env, synth_json):
    # Set up environment for TCL weirdness
    env = environ.copy()
    env.update(tcl_env)
    return common_sub('yosys', '-p', f'read_json {synth_json}; tcl {tcl}', env=env)


class SynthModule(Module):
    extra_products: 'list[str]'

    def map_io(self, ctx: ModuleContext):
        mapping = {}

        top = ctx.values.top
        if ctx.takes.build_dir:
            top = str(Path(ctx.takes.build_dir) / top)
        mapping['eblif'] = top + '.eblif'
        mapping['fasm_extra'] = top + '_fasm_extra.fasm'
        mapping['json'] = top + '.json'
        mapping['synth_json'] = top + '_io.json'

        for extra in self.extra_products:
            name, spec = decompose_depname(extra)
            if spec == 'maybe':
                raise ModuleRuntimeException(
                    f'Yosys synth extra products can\'t use \'maybe\ '
                    f'(?) specifier. Product causing this error: `{extra}`.'
                )
            elif spec == 'req':
                mapping[name] = str(Path(top).parent / f'{ctx.values.device}_{name}.{name}')

        return mapping

    def execute(self, ctx: ModuleContext):
        tcl_env = yosys_setup_tcl_env(ctx.values.yosys_tcl_env) \
            if ctx.values.yosys_tcl_env else {}
        split_inouts = Path(tcl_env["UTILS_PATH"]) / 'split_inouts.py'

        if get_verbosity_level() >= 2:
            yield f'Synthesizing sources: {ctx.takes.sources}...'
        else:
            yield f'Synthesizing sources...'

        yosys_synth(
            str(get_tcl_wrapper_path('synth')),
            tcl_env,
            ctx.takes.sources,
            ctx.values.read_verilog_args,
            ctx.outputs.synth_log
        )

        yield f'Splitting in/outs...'
        common_sub('python3', str(split_inouts), '-i', ctx.outputs.json, '-o',
            ctx.outputs.synth_json)

        if not Path(ctx.produces.fasm_extra).is_file():
            with Path(ctx.produces.fasm_extra).open('w') as wfptr:
                wfptr.write('')

        yield f'Converting...'
        yosys_conv(
            str(get_tcl_wrapper_path('conv')),
            tcl_env,
            ctx.outputs.synth_json
        )

    def __init__(self, params):
        self.name = 'synthesize'
        self.no_of_phases = 3
        self.takes = [
            'sources',
            'build_dir?'
        ]
        # Extra takes for use with TCL scripts
        extra_takes = params.get('takes')
        if extra_takes:
            self.takes += extra_takes

        self.produces = [
            'eblif',
            'fasm_extra',
            'json',
            'synth_json',
            'synth_log!'
        ]
        # Extra products for use with TCL scripts
        extra_products = params.get('produces')
        if extra_products:
            self.produces += extra_products
            self.extra_products = extra_products
        else:
            self.extra_products = []

        self.values = [
            'top',
            'device',
            'tcl_scripts',
            'yosys_tcl_env?',
            'read_verilog_args?'
        ]
        self.prod_meta = {
            'eblif': 'Extended BLIF hierarchical sequential designs file\n'
                     'generated by YOSYS',
            'json': 'JSON file containing a design generated by YOSYS',
            'synth_log': 'YOSYS synthesis log',
            'fasm_extra': 'Extra FASM generated during sythesis stage. Needed in '
                          'some designs.\nIn case it\'s not necessary, the file '
                          'will be empty.'
        }
        extra_meta = params.get('prod_meta')
        if extra_meta:
            self.prod_meta.update(extra_meta)

ModuleClass = SynthModule
