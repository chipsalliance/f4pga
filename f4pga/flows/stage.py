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

from f4pga.flows.common import decompose_depname, resolve_modstr, ResolutionEnv
from f4pga.flows.module import Module
from f4pga.flows.runner import get_module, module_io


class StageIO:
    """
    Stage dependency input/output.
    TODO: Solve the inconsistecy between usage of that and usage of `decompose_depname` with an unprocessed string.
    """

    name: str  # A symbolic name given to the dependency
    spec: str

    def __init__(self, encoded_name: str):
        """
        Encoded name feauters special characters that imply certain qualifiers.
        Any name that ends with '?' is treated as with 'maybe' qualifier.
        The '?' Symbol is then dropped from the dependency name.
        """

        self.name, self.spec = decompose_depname(encoded_name)

    def __repr__(self) -> str:
        return "StageIO { name: '" + self.name + "', spec: " + self.spec + "}"


class Stage:
    """
    Represents a single stage in a flow.
    I.e an instance of a module with a local set of values.
    """

    module: Module

    # Name of the stage (module's name)
    name: str

    # List of symbolic names of dependencies used by the stage
    takes: "list[StageIO]"

    # List of symbolic names of dependencies produced by the stage
    produces: "list[StageIO]"

    # Stage-specific values
    value_overrides: "dict[str, ]"

    # Stage's metadata extracted from module's output.
    meta: "dict[str, str]"

    def __init__(self, name: str, stage_def: "dict[str, ]", r_env: ResolutionEnv):
        self.name = name

        if stage_def is None:
            stage_def = {}

        self.module = get_module(resolve_modstr(stage_def["module"]))(stage_def.get("params"), r_env, name)

        values = stage_def.get("values")
        self.value_overrides = values if values is not None else {}

        mod_io = module_io(self.module)
        self.takes = [StageIO(input) for input in mod_io["takes"]]
        self.produces = [StageIO(input) for input in mod_io["produces"]]
        self.meta = mod_io["meta"]

    def __repr__(self) -> str:
        return (
            "Stage '" + self.name + "' {"
            f" value_overrides: {self.value_ovds},"
            f" args: {self.args},"
            f" takes: {self.takes},"
            f" produces: {self.produces} " + "}"
        )
