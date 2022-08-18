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

from f4pga.flows.common import vpr_specific_values, vpr as common_vpr, VprArgs, save_vpr_log
from f4pga.flows.module import Module, ModuleContext


def default_output_name(place_constraints):
    m = re_match('(.*)\\.[^.]*$', place_constraints)
    if m:
        return m.groups()[0] + '.place'
    return f'{place_constraints}.place'


def place_constraints_file(ctx: ModuleContext):
    if ctx.takes.place_constraints:
        return ctx.takes.place_constraints, False
    if ctx.takes.io_place:
        return ctx.takes.io_place, False
    return f'{Path(ctx.takes.eblif).stem}.place', True


class PlaceModule(Module):
    def map_io(self, ctx: ModuleContext):
        p, _ = place_constraints_file(ctx)
        return {
            'place': default_output_name(p)
        }

    def execute(self, ctx: ModuleContext):
        place_constraints, dummy = place_constraints_file(ctx)
        place_constraints = Path(place_constraints).resolve()
        if dummy:
            with place_constraints.open('wb') as wfptr:
                wfptr.write(b'')

        build_dir = Path(ctx.takes.eblif).parent

        yield 'Running VPR...'
        common_vpr(
            'place',
            VprArgs(
                ctx.share,
                ctx.takes.eblif,
                ctx.values,
                sdc_file=ctx.takes.sdc,
                vpr_extra_opts=['--fix_clusters', place_constraints]
            ),
            cwd=build_dir
        )

        # VPR names output on its own. If user requested another name, the
        # output file should be moved.
        # TODO: This extends the set of names that would cause collisions.
        # As for now (22-07-2021), no collision detection is being done, but
        # when the problem gets tackled, we should keep in mind that VPR-based
        # modules may produce some temporary files with names that differ from
        # the ones in flow configuration.
        if ctx.is_output_explicit('place'):
            Path(default_output_name(str(place_constraints))).rename(ctx.outputs.place)

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
