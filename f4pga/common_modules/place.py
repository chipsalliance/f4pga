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
import os
from shutil import move as sh_mv
from re import match as re_match
from f4pga.common import *
from f4pga.module import Module, ModuleContext


def default_output_name(place_constraints):
    p = place_constraints
    m = re_match('(.*)\\.[^.]*$', place_constraints)
    if m:
        return m.groups()[0] + '.place'
    return f'{p}.place'


def place_constraints_file(ctx: ModuleContext):
    p = ctx.takes.place_constraints
    if p:
        return p, False
    p = ctx.takes.io_place
    if p:
        return p, False
    return f'{Path(ctx.takes.eblif).stem}.place', True


class PlaceModule(Module):
    def map_io(self, ctx: ModuleContext):
        mapping = {}
        p, _ = place_constraints_file(ctx)

        mapping['place'] = default_output_name(p)
        return mapping

    def execute(self, ctx: ModuleContext):
        place_constraints, dummy = place_constraints_file(ctx)
        place_constraints = os.path.realpath(place_constraints)
        if dummy:
            with open(place_constraints, 'wb') as f:
                f.write(b'')

        build_dir = str(Path(ctx.takes.eblif).parent)

        vpr_options = ['--fix_clusters', place_constraints]

        yield 'Running VPR...'
        vprargs = VprArgs(ctx.share, ctx.takes.eblif, ctx.values,
                          sdc_file=ctx.takes.sdc, vpr_extra_opts=vpr_options)
        vpr('place', vprargs, cwd=build_dir)

        # VPR names output on its own. If user requested another name, the
        # output file should be moved.
        # TODO: This extends the set of names that would cause collisions.
        # As for now (22-07-2021), no collision detection is being done, but
        # when the problem gets tackled, we should keep in mind that VPR-based
        # modules may produce some temporary files with names that differ from
        # the ones in flow configuration.
        if ctx.is_output_explicit('place'):
            output_file = default_output_name(place_constraints)
            sh_mv(output_file, ctx.outputs.place)

        yield 'Saving log...'
        save_vpr_log('place.log', build_dir=build_dir)

    def __init__(self, _):
        self.name = 'place'
        self.no_of_phases = 2
        self.takes = [
            'eblif',
            'sdc?',
            'place_constraints?',
            'io_place?'
        ]
        self.produces = [ 'place' ]
        self.values = [
            'device',
            'vpr_options?'
        ] + vpr_specific_values()

ModuleClass = PlaceModule
