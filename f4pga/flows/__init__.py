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
F4PGA Build System

This tool allows for building FPGA targets (such as bitstreams) for any supported platform with just one simple command
and a project file.

The idea is that F4PGA wraps all the tools needed by different platforms in "modules", which define inputs/outputs and
various parameters.
This allows F4PGA to resolve dependencies for any target provided that a "flow definition" file exists for such target.
The flow defeinition file list modules available for that platform and may tweak some settings of those modules.

A basic example of using F4PGA:

$ f4pga build --flow flow.json --part XC7A35TCSG324-1 -t bitstream

This will make F4PGA attempt to create a bitstream for arty_35 platform.
``flow.json`` is a flow configuration file, which should be created for a project that uses F4PGA.
Contains project-specific definitions needed within the flow, such as list of source code files.
"""

from typing import Iterable

from f4pga.flows.stage import Stage
from f4pga.flows.common import set_verbosity_level, sfprint
from f4pga.flows.argparser import setup_argparser
from f4pga.flows.commands import cmd_build, cmd_show_dependencies, cmd_run_util, f4pga_done


def platform_stages(platform_flow, r_env):
    """Iterates over all stages available in a given flow."""

    stage_options = platform_flow.get("stage_options")
    for stage_name, modulestr in platform_flow["stages"].items():
        mod_opts = stage_options.get(stage_name) if stage_options else None
        yield Stage(stage_name, modulestr, mod_opts, r_env)


def get_stage_values_override(og_values: dict, stage: Stage):
    values = og_values.copy()
    values.update(stage.value_ovds)
    return values


def prepare_stage_io_input(stage: Stage):
    return {"params": stage.params} if stage.params is not None else {}


def main():
    parser = setup_argparser()
    args = parser.parse_args()

    set_verbosity_level(args.verbose - (1 if args.silent else 0))

    if args.command == "build":
        cmd_build(args)
        f4pga_done()

    if args.command == "showd":
        cmd_show_dependencies(args)
        f4pga_done()

    if args.command == "utils":
        cmd_run_util(args)
        f4pga_done()

    sfprint(0, "Please use a command.\nUse `--help` flag to learn more.")
    f4pga_done()


if __name__ == "__main__":
    main()
