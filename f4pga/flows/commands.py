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

from typing import Iterable
from pathlib import Path
from os import environ
from argparse import Namespace

from colorama import Fore, Style
from yaml import load as yaml_load, Loader as yaml_loader

from f4pga.context import FPGA_FAM
from f4pga.flows.common import (
    bin_dir_path,
    share_dir_path,
    aux_dir_path,
    F4PGAException,
    ResolutionEnv,
    fatal,
    scan_modules,
    set_verbosity_level,
    sfprint,
    sub as common_sub,
)
from f4pga.flows.argparser import get_cli_flow_config
from f4pga.flows.cache import F4Cache
from f4pga.flows.flow_config import (
    ProjectFlowConfig,
    FlowConfig,
    FlowDefinition,
    open_project_flow_cfg,
    override_prj_flow_cfg_by_cli,
    verify_platform_name,
)
from f4pga.flows.flow import Flow
from f4pga.flows.stage import Stage
from f4pga.flows.inspector import get_module_info


ROOT = Path(__file__).resolve().parent

F4CACHEPATH = ".f4cache"


def display_dep_info(stages: "Iterable[Stage]"):
    sfprint(0, "Platform dependencies/targets:")
    longest_out_name_len = 0
    for stage in stages:
        for out in stage.produces:
            l = len(out.name)
            if l > longest_out_name_len:
                longest_out_name_len = l

    desc_indent = longest_out_name_len + 7
    nl_indentstr = "\n"
    for _ in range(0, desc_indent):
        nl_indentstr += " "

    for stage in stages:
        for out in stage.produces:
            pname = Style.BRIGHT + out.name + Style.RESET_ALL
            indent = ""
            for _ in range(0, desc_indent - len(pname) + 3):
                indent += " "
            specstr = "???"
            if out.spec == "req":
                specstr = f"{Fore.BLUE}guaranteed{Fore.RESET}"
            elif out.spec == "maybe":
                specstr = f"{Fore.YELLOW}not guaranteed{Fore.RESET}"
            elif out.spec == "demand":
                specstr = f"{Fore.RED}on-demand{Fore.RESET}"
            pgen = f"{Style.DIM}stage: `{stage.name}`, " f"spec: {specstr}{Style.RESET_ALL}"
            pdesc = stage.meta[out.name].replace("\n", nl_indentstr)
            sfprint(0, f"    {Style.BRIGHT + out.name + Style.RESET_ALL}:" f"{indent}{pdesc}{nl_indentstr}{pgen}")


def display_stage_info(stage: Stage):
    if stage is None:
        sfprint(0, f"Stage  does not exist")
        f4pga_fail()
        return

    sfprint(0, f"Stage `{Style.BRIGHT}{stage.name}{Style.RESET_ALL}`:")
    sfprint(0, f"  Module: `{Style.BRIGHT}{stage.module.name}{Style.RESET_ALL}`")
    sfprint(0, f"  Module info:")

    mod_info = get_module_info(stage.module)
    mod_info = "\n    ".join(mod_info.split("\n"))

    sfprint(0, f"    {mod_info}")


f4pga_done_str = Style.BRIGHT + Fore.GREEN + "DONE"


def f4pga_fail():
    global f4pga_done_str
    f4pga_done_str = Style.BRIGHT + Fore.RED + "FAILED"


def f4pga_done():
    sfprint(1, f"f4pga: {f4pga_done_str}" f"{Style.RESET_ALL + Fore.RESET}")
    exit(0)


def setup_resolution_env():
    """Sets up a ResolutionEnv with default built-ins."""

    r_env = ResolutionEnv({"shareDir": share_dir_path, "binDir": bin_dir_path, "auxDir": aux_dir_path})

    def _noisy_warnings():
        """
        Emit some noisy warnings.
        """
        environ["OUR_NOISY_WARNINGS"] = "noisy_warnings.log"
        return "noisy_warnings.log"

    def _generate_values():
        """
        Generate initial values, available in configs.
        """
        conf = {
            "python3": common_sub("which", "python3").decode().replace("\n", ""),
            "noisyWarnings": _noisy_warnings(),
        }
        if FPGA_FAM == "xc7":
            conf["prjxray_db"] = common_sub("prjxray-config").decode().replace("\n", "")

        return conf

    r_env.add_values(_generate_values())
    return r_env


def open_project_flow_config(path: str) -> ProjectFlowConfig:
    try:
        flow_cfg = open_project_flow_cfg(path)
    except FileNotFoundError as _:
        fatal(-1, "The provided flow configuration file does not exist")
    return flow_cfg


def verify_part_stage_params(flow_cfg: FlowConfig, part: "str | None" = None):
    if part:
        platform_name = get_platform_name_for_part(part)
        if not verify_platform_name(platform_name, str(ROOT)):
            sfprint(0, f"Platform `{part}`` is unsupported.")
            return False
        if part not in flow_cfg.part():
            sfprint(0, f"Platform `{part}`` is not in project.")
            return False

    return True


def get_platform_name_for_part(part_name: str):
    """
    Gets a name that identifies the platform setup required for a specific chip.
    The reason for such distinction is that plenty of chips with different names
    differ only in a type of package they use.
    """
    with (ROOT / "part_db.yml").open("r") as rfptr:
        for key, val in yaml_load(rfptr, yaml_loader).items():
            if part_name.upper() in val:
                return key
        raise Exception(f"Unknown part name <{part_name}>!")


def make_flow_config(project_flow_cfg: ProjectFlowConfig, part_name: str) -> FlowConfig:
    """Create `FlowConfig` from given project flow configuration and part name"""

    platform = get_platform_name_for_part(part_name)
    if platform is None:
        raise F4PGAException(message="You have to specify a part name or configure a default part.")

    if part_name not in project_flow_cfg.parts():
        raise F4PGAException(message="Project flow configuration does not support requested part.")

    r_env = setup_resolution_env()
    r_env.add_values({"part_name": part_name.lower()})

    scan_modules(str(ROOT))

    with (ROOT / "platforms.yml").open("r") as rfptr:
        platforms = yaml_load(rfptr, yaml_loader)
    if platform not in platforms:
        raise F4PGAException(message=f"Flow definition for platform <{platform}> cannot be found!")

    flow_cfg = FlowConfig(project_flow_cfg, FlowDefinition(platforms[platform], r_env), part_name)

    if len(flow_cfg.stages) == 0:
        raise F4PGAException(message="Platform flow does not define any stage")

    return flow_cfg


def cmd_build(args: Namespace):
    """`build` command implementation"""

    project_flow_cfg: ProjectFlowConfig = None

    part_name = args.part

    if args.flow:
        project_flow_cfg = open_project_flow_config(args.flow)
    elif part_name is not None:
        project_flow_cfg = ProjectFlowConfig(".temp.flow.json")
    if part_name is None and project_flow_cfg is not None:
        part_name = project_flow_cfg.get_default_part()

    if (project_flow_cfg is None) and part_name is None:
        fatal(-1, "No configuration was provided. Use `--flow`, and/or " "`--part` to configure flow.")

    override_prj_flow_cfg_by_cli(project_flow_cfg, get_cli_flow_config(args, part_name))

    flow_cfg = make_flow_config(project_flow_cfg, part_name)

    if args.info:
        display_dep_info(flow_cfg.stages.values())
        f4pga_done()

    if args.stageinfo:
        display_stage_info(flow_cfg.stages.get(args.stageinfo[0]))
        f4pga_done()

    target = args.target
    if target is None:
        target = project_flow_cfg.get_default_target(part_name)
        if target is None:
            fatal(-1, "Please specify desired target using `--target` option " "or configure a default target.")

    flow = Flow(target=target, cfg=flow_cfg, f4cache=F4Cache(F4CACHEPATH) if not args.nocache else None)

    dep_print_verbosity = 0 if args.pretend else 2
    sfprint(dep_print_verbosity, "\nProject status:")
    flow.print_resolved_dependencies(dep_print_verbosity)
    sfprint(dep_print_verbosity, "")

    if args.pretend:
        f4pga_done()

    try:
        flow.execute()
    except AssertionError as e:
        raise e
    except Exception as e:
        sfprint(0, f"{e}")
        f4pga_fail()

    if flow.f4cache:
        flow.f4cache.save()


def cmd_show_dependencies(args: Namespace):
    """`showd` command implementation"""

    flow_cfg = open_project_flow_config(args.flow)

    if not verify_part_stage_params(flow_cfg, args.part):
        f4pga_fail()
        return

    platform_overrides: "set | None" = None
    if args.platform is not None:
        platform_overrides = set(flow_cfg.get_dependency_platform_overrides(args.part).keys())

    display_list = []

    raw_deps = flow_cfg.get_dependencies_raw(args.platform)

    for dep_name, dep_paths in raw_deps.items():
        prstr: str
        if (platform_overrides is not None) and (dep_name in platform_overrides):
            prstr = (
                f"{Style.DIM}({args.platform}){Style.RESET_ALL} "
                f"{Style.BRIGHT + dep_name + Style.RESET_ALL}: {dep_paths}"
            )
        else:
            prstr = f"{Style.BRIGHT + dep_name + Style.RESET_ALL}: {dep_paths}"

        display_list.append((dep_name, prstr))

    display_list.sort(key=lambda p: p[0])

    for _, prstr in display_list:
        sfprint(0, prstr)

    set_verbosity_level(-1)
