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

from f4pga.common import decompose_depname, resolve_modstr
from f4pga.module import Module
from f4pga.module_runner import get_module, module_io

class StageIO:
    """
    Stage dependency input/output.
    TODO: Solve the inconsistecy between usage of that and usage of
          `decompose_depname` with an unprocessed string.
    """

    name: str       # A symbolic name given to the dependency
    spec: str

    def __init__(self, encoded_name: str):
        """
        Encoded name feauters special characters that imply certain qualifiers.
        Any name that ends with '?' is treated as with 'maybe' qualifier.
        The '?' Symbol is then dropped from the dependency name.
        """

        self.name, self.spec = decompose_depname(encoded_name)

    def __repr__(self) -> str:
        return 'StageIO { name: \'' + self.name + '\', spec: ' + \
               self.spec + '}'

class Stage:
    """
    Represents a single stage in a flow. I.e an instance of a module with a
    local set of values.
    """

    name: str                  #   Name of the stage (module's name)
    takes: 'list[StageIO]'     #   List of symbolic names of dependencies used by
                               # the stage
    produces: 'list[StageIO]'  #   List of symbolic names of dependencies
                               # produced by the stage
    value_overrides: 'dict[str, ]'      # Stage-specific values
    module: Module
    meta: 'dict[str, str]'     #   Stage's metadata extracted from module's
                               # output.

    def __init__(self, name: str, modstr: str, mod_opts: 'dict[str, ] | None'):
        if mod_opts is None:
            mod_opts = {}

        module_path = resolve_modstr(modstr)
        ModuleClass = get_module(module_path)
        self.module = ModuleClass(mod_opts.get('params'))

        values = mod_opts.get('values')
        if values is not None:
            self.value_overrides = values
        else:
            self.value_overrides = {}

        mod_io = module_io(self.module)
        self.name = name

        self.takes = []
        for input in mod_io['takes']:
            io = StageIO(input)
            self.takes.append(io)

        self.produces = []
        for input in mod_io['produces']:
            io = StageIO(input)
            self.produces.append(io)

        self.meta = mod_io['meta']

    def __repr__(self) -> str:
        return 'Stage \'' + self.name + '\' {' \
               f' value_overrides: {self.value_ovds},' \
               f' args: {self.args},' \
               f' takes: {self.takes},' \
               f' produces: {self.produces} ' + '}'
