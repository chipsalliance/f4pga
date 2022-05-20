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
from f4pga.common import *
from f4pga.module import Module, ModuleContext


class PlaceConstraintsModule(Module):
    def map_io(self, ctx: ModuleContext):
        return {
            'place_constraints': f'{Path(ctx.takes.net).stem!s}.preplace'
        }

    def execute(self, ctx: ModuleContext):
        arch_dir = str(Path(ctx.share) / 'arch')
        arch_def = str(Path(arch_dir) / ctx.values.device / 'arch.timing.xml')

        database = sub('prjxray-config').decode().replace('\n', '')

        yield 'Generating .place...'

        extra_opts: 'list[str]'
        if ctx.values.extra_opts:
            extra_opts = options_dict_to_list(ctx.values.extra_opts)
        else:
            extra_opts = []

        data = sub(*(['python3', ctx.values.script,
                      '--net', ctx.takes.net,
                      '--arch', arch_def,
                      '--blif', ctx.takes.eblif,
                      '--input', ctx.takes.io_place,
                      '--db_root', database,
                      '--part', ctx.values.part_name]
                      + extra_opts))

        yield 'Saving place constraint data...'
        with open(ctx.outputs.place_constraints, 'wb') as f:
            f.write(data)

    def __init__(self, _):
        self.name = 'place_constraints'
        self.no_of_phases = 2
        self.takes = [
            'eblif',
            'net',
            'io_place'
        ]
        self.produces = [ 'place_constraints' ]
        self.values = [
            'device',
            'part_name',
            'script',
            'extra_opts?'
        ]

ModuleClass = PlaceConstraintsModule
