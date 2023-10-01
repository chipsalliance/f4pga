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
from copy import copy
from os import listdir as os_listdir
from json import dump as json_dump, load as json_load

from f4pga.flows.common import ResolutionEnv, deep
from f4pga.flows.stage import Stage


def open_flow_cfg(path: str) -> dict:
    with Path(path).open("r") as rfptr:
        return json_load(rfptr)


def p_get_ovs_raw(dict_name: str, flow_cfg, part: "str | None", stage: "str | None"):
    vals = flow_cfg.get(dict_name)
    if vals is None:
        vals = {}
    if part is not None:
        platform_vals = flow_cfg[part].get(dict_name)
        if platform_vals is not None:
            vals.update(platform_vals)
        if stage is not None:
            stage_deps = flow_cfg[part][stage].get(dict_name)
            if stage_deps is not None:
                vals.update(stage_deps)

    return vals


def verify_platform_name(platform: str, mypath: str):
    for plat_def_filename in os_listdir(str(Path(mypath) / "platforms")):
        platform_name = str(Path(plat_def_filename).stem)
        if platform == platform_name:
            return True
    return False


class FlowDefinition:
    stages: "dict[str, Stage]"  # stage name -> module path mapping
    r_env: ResolutionEnv

    def __init__(self, flow_def: dict, r_env: ResolutionEnv):
        self.flow_def = flow_def
        self.r_env = r_env
        self.stages = {}

        global_vals = flow_def.get("values")
        if global_vals is not None:
            self.r_env.add_values(global_vals)

        for stage_name, stage_def in flow_def["stages"].items():
            self.stages[stage_name] = Stage(stage_name, stage_def)

    def stage_names(self):
        return self.stages.keys()


KWORDS = {"dependencies", "values", "default_platform", "default_target"}


class ProjectFlowConfig:
    flow_cfg: dict
    path: str

    def __init__(self, path: str):
        self.flow_cfg = {}
        self.path = copy(path)

    def parts(self):
        for part in self.flow_cfg.keys():
            if part not in KWORDS:
                yield part

    def get_default_part(self) -> "str | None":
        return self.flow_cfg.get("default_part")

    def get_default_target(self, part: str) -> "str | None":
        return self.flow_cfg[part].get("default_target")

    def get_dependencies_raw(self, part: "str | None" = None):
        """
        Get dependencies without value resolution applied.
        """
        return p_get_ovs_raw("dependencies", self.flow_cfg, part, None)

    def get_values_raw(self, part: "str | None" = None, stage: "str | None" = None):
        """
        Get values without value resolution applied.
        """
        return p_get_ovs_raw("values", self.flow_cfg, part, stage)

    def get_stage_value_overrides(self, part: str, stage: str):
        stage_vals_ovds = {}

        vals = self.flow_cfg.get("values")
        if vals is not None:
            stage_vals_ovds.update(vals)
        stage_cfg = self.flow_cfg[part].get(stage)
        if stage_cfg is not None:
            vals = stage_cfg.get("values")
            if vals is not None:
                stage_vals_ovds.update(vals)

        return stage_vals_ovds

    def get_dependency_platform_overrides(self, part: str):
        platform_ovds = self.flow_cfg[part].get("dependencies")
        if platform_ovds is None:
            return {}
        return platform_ovds


def override_prj_flow_cfg_by_cli(cfg: ProjectFlowConfig, cli_d: "dict[str, dict[str, dict]]"):
    if "dependencies" not in cfg.flow_cfg:
        cfg.flow_cfg["dependencies"] = {}
    if "values" not in cfg.flow_cfg:
        cfg.flow_cfg["values"] = {}
    cfg.flow_cfg["dependencies"] = {**cfg.flow_cfg["dependencies"], **cli_d["dependencies"]}
    cfg.flow_cfg["values"] = {**cfg.flow_cfg["values"], **cli_d["values"]}
    return cfg


class FlowConfig:
    part: str
    r_env: ResolutionEnv
    dependencies_explicit: "dict[str, ]"
    stages: "dict[str, Stage]"

    def __init__(self, project_config: ProjectFlowConfig, platform_def: FlowDefinition, part: str):
        self.r_env = platform_def.r_env
        self.r_env.add_values(project_config.get_values_raw(part))
        self.stages = platform_def.stages
        self.part = part

        self.dependencies_explicit = deep(lambda p: str(Path(p).resolve()), allow_none=True)(
            self.r_env.resolve(project_config.get_dependencies_raw(part))
        )

        for stage_name, stage in platform_def.stages.items():
            project_val_ovds = project_config.get_stage_value_overrides(part, stage_name)
            stage.value_overrides.update(project_val_ovds)

    def get_dependency_overrides(self):
        return self.dependencies_explicit

    def get_r_env(self, stage_name: str) -> ResolutionEnv:
        stage = self.stages[stage_name]
        r_env = copy(self.r_env)
        r_env.add_values(stage.value_overrides)

        return r_env

    def get_stage(self, stage_name: str) -> Stage:
        return self.stages[stage_name]


class FlowConfigException(Exception):
    path: str
    message: str

    def __init__(self, path: str, message: str):
        self.path = path
        self.message = message

    def __str__(self) -> str:
        return f"Error in config `{self.path}: {self.message}"


def open_project_flow_cfg(path: str) -> ProjectFlowConfig:
    cfg = ProjectFlowConfig(path)
    with Path(path).open("r") as rfptr:
        cfg.flow_cfg = json_load(rfptr)
    return cfg
