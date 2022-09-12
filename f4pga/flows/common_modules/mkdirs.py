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

"""
This module is used as a helper in a abuild chain to automate creating build directiores.
It's currenty the only parametric module, meaning it can take user-provided input at an early stage in order to
determine its take/produces I/O.
This allows other repesenting configurable directories, such as a build directory as dependencies and by doing so, allow
the dependency algorithm to lazily create the directories if they become necessary.
"""

from pathlib import Path

from f4pga.flows.module import Module, ModuleContext


class MkDirsModule(Module):
    deps_to_produce: "dict[str, str]"

    def map_io(self, ctx: ModuleContext):
        return ctx.r_env.resolve(self.deps_to_produce)

    def execute(self, ctx: ModuleContext):
        outputs = vars(ctx.outputs)
        for _, path in outputs.items():
            yield f"Creating directory {path}..."
            Path(path).mkdir(parents=True, exist_ok=True)

    def __init__(self, params, r_env, instance_name):
        super().__init__(params, r_env, instance_name)
        self.no_of_phases = len(params) if params else 0
        self.takes = []
        self.produces = list(params.keys()) if params else []
        self.values = []
        self.deps_to_produce = params


ModuleClass = MkDirsModule
