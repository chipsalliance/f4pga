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

import os
from f4pga.common import *
from f4pga.module import Module, ModuleContext


def yosys_setup_tcl_env(tcl_env_def):
    """
    Setup environmental variables for YOSYS TCL scripts.
    """
    env = {}
    for key, value in tcl_env_def.items():
        if value is None:
            continue
        v = value
        if type(value) is list:
            v = ' '.join(value)
        env[key] = v
    return env


def yosys_synth(tcl, tcl_env, verilog_files=[], read_verilog_args=None, log=None):
    # Set up environment for TCL weirdness
    optional = []
    if log:
        optional += ['-l', log]
    env = os.environ.copy()
    env.update(tcl_env)

    tcl = f'tcl {tcl}'

    # Use append read_verilog commands to the scripts for more sophisticated
    # input if arguments are specified. Omit direct input throught `yosys` command.
    if read_verilog_args:
        args_str = ' '.join(read_verilog_args)
        for verilog in verilog_files:
            tcl = f'read_verilog {args_str} {verilog}; {tcl}'
        verilog_files = []

    # Execute YOSYS command
    return sub(*(['yosys', '-p', tcl] + optional + verilog_files), env=env)


def yosys_conv(tcl, tcl_env, synth_json):
    # Set up environment for TCL weirdness
    env = os.environ.copy()
    env.update(tcl_env)
    return sub('yosys', '-p', f'read_json {synth_json}; tcl {tcl}', env=env)


class SynthModule(Module):
    extra_products: 'list[str]'

    def map_io(self, ctx: ModuleContext):
        mapping = {}

        top = ctx.values.top
        if ctx.takes.build_dir:
            top = os.path.join(ctx.takes.build_dir, top)
        mapping['eblif'] = top + '.eblif'
        mapping['fasm_extra'] = top + '_fasm_extra.fasm'
        mapping['json'] = top + '.json'
        mapping['synth_json'] = top + '_io.json'

        b_path = os.path.dirname(top)

        for extra in self.extra_products:
            name, spec = decompose_depname(extra)
            if spec == 'maybe':
                raise ModuleRuntimeException(
                    f'Yosys synth extra products can\'t use \'maybe\ '
                    f'(?) specifier. Product causing this error: `{extra}`.'
                )
            elif spec == 'req':
                mapping[name] = \
                    os.path.join(b_path,
                                 ctx.values.device + '_' + name + '.' + name)

        return mapping

    def execute(self, ctx: ModuleContext):
        split_inouts = os.path.join(ctx.share, 'scripts/split_inouts.py')
        synth_tcl = os.path.join(ctx.values.tcl_scripts, 'synth.tcl')
        conv_tcl = os.path.join(ctx.values.tcl_scripts, 'conv.tcl')

        tcl_env = yosys_setup_tcl_env(ctx.values.yosys_tcl_env) \
            if ctx.values.yosys_tcl_env else {}

        if get_verbosity_level() >= 2:
            yield f'Synthesizing sources: {ctx.takes.sources}...'
        else:
            yield f'Synthesizing sources...'

        yosys_synth(synth_tcl, tcl_env, ctx.takes.sources,
                    ctx.values.read_verilog_args, ctx.outputs.synth_log)

        yield f'Splitting in/outs...'
        sub('python3', split_inouts, '-i', ctx.outputs.json, '-o',
            ctx.outputs.synth_json)

        if not os.path.isfile(ctx.produces.fasm_extra):
            with open(ctx.produces.fasm_extra, 'w') as f:
                f.write('')

        yield f'Converting...'
        yosys_conv(conv_tcl, tcl_env, ctx.outputs.synth_json)

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
