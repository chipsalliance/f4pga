#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright (C) 2022 F4PGA Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

import pathlib
from f4pga.flows.module import *
from f4pga.flows.tools.nextpnr import NextPnrBaseModule

import re
from pathlib import Path

class Ice40ChipInfo:
    subfamily: str
    size: str
    package_code: str

    def __init__(self, part_name: str):
        m = re.match('ICE40([A-Z]*)([0-9]+[A-Z]?)-([A-Z0-9]*)$', part_name.upper())
        assert m is not None

        self.subfamily = m.group(1)
        self.size = m.group(2)
        self.package_code = m.group(3)

class NextPnrModule(NextPnrBaseModule):
    def map_io(self, ctx: ModuleContext) -> 'dict[str, ]':
        return {
            'ice_asm': str(Path(ctx.takes.json).with_suffix('.ice'))
        }

    def execute(self, ctx: ModuleContext):
        chip_info = Ice40ChipInfo(ctx.values.part_name)

        self.extra_nextpnr_opts = [
            f'--{(chip_info.subfamily + chip_info.size).lower()}',
            f'--package', chip_info.package_code.lower(),
            f'--asc', ctx.outputs.ice_asm
        ]

        if ctx.takes.pcf is not None:
            self.extra_nextpnr_opts += ['--pcf', ctx.takes.pcf]
        else:
            self.extra_nextpnr_opts += ['--pcf-allow-unconstrained']

        return super().execute(ctx)

    def __init__(self, params: 'dict[str, ]', r_env: ResolutionEnv,
                 instance_name: str = '<anonymous>'):
        super().__init__(params, r_env, instance_name, interchange=False)

        self.nextpnr_variant = 'ice40'

        self.takes += [
            'pcf?'
        ]

        self.values += [
            'part_name'
        ]

        self.produces += [
            'ice_asm'
        ]

ModuleClass = NextPnrModule
