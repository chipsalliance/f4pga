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
Utility scripts handler
"""

from subprocess import check_call
from shutil import which
from os import environ, strerror
from pathlib import Path
import errno
import json
import pkgutil

# import warnings
import importlib

import f4pga.aux.utils
from f4pga.flows.common import sfprint

# from f4pga.aux.utils import *


class Util:
    """
    Wrapper for internal python utils
    """

    def _set_fpga_data(self):
        fpga_map = open(self.root_dir / "fpga_map.json")
        fmap = json.load(fpga_map)

        self.architectures = fmap.keys()

        for fpga_fam, fpga_data in fmap.items():
            if self.fpga_fam == fpga_fam:
                self.manufacturer = fpga_data["manufacturer"]
                if "architecture" in fpga_data.keys():
                    self.arch = fpga_data["architecture"]
                    self.subarch = fpga_fam
                else:
                    self.arch = fpga_fam
                    self.subarch = None
                break

    def __init__(self, name, function, args):
        self.name = name
        self.function = function
        self.args = args
        self.env = environ.copy()
        self.fpga_fam = self.env.get("FPGA_FAM", "xc7")
        self.root_dir = Path(__file__).resolve().parent
        self._set_fpga_data()

    def _get_util_path(self):
        man = self.manufacturer
        arch = self.arch
        subarch = self.subarch
        script_name = self.name + ".py"

        if subarch is not None:
            util_path = "f4pga.aux.utils." + man + "." + arch + "." + subarch + "." + self.name
            subarch_path = self.root_dir / "aux" / "utils" / man / arch / subarch / script_name
            if subarch_path.is_file():
                return util_path

        util_path = "f4pga.aux.utils." + man + "." + arch + "." + self.name
        arch_path = self.root_dir / "aux" / "utils" / man / arch / script_name
        if arch_path.is_file():
            return util_path

        util_path = "f4pga.aux.utils." + man + "." + self.name
        manufacturer_path = self.root_dir / "aux" / "utils" / man / script_name
        if manufacturer_path.is_file():
            return util_path

        # Look through other directories common for the manufacturer
        manufacturer_path = (self.root_dir / "aux" / "utils" / man).rglob("*")
        manufacturer_dirs = [
            man_dir.stem for man_dir in manufacturer_path if (man_dir.is_dir() and man_dir not in self.architectures)
        ]
        for man_dir in manufacturer_dirs:
            util_path = "f4pga.aux.utils." + man + "." + man_dir + "." + self.name
            manufacturer_path = self.root_dir / "aux" / "utils" / man / man_dir / script_name
            if manufacturer_path.is_file():
                return util_path

        util_path = "f4pga.aux.utils." + self.name
        common_path = self.root_dir / "aux" / "utils" / script_name
        if common_path.is_file():
            return util_path
        else:
            if subarch is not None:
                raise FileNotFoundError(
                    errno.ENOENT,
                    strerror(errno.ENOENT),
                    str(common_path)
                    + " or "
                    + str(manufacturer_path)
                    + " or "
                    + str(arch_path)
                    + " or "
                    + str(subarch_path),
                )
            else:
                raise FileNotFoundError(
                    errno.ENOENT,
                    strerror(errno.ENOENT),
                    str(common_path) + " or " + str(manufacturer_path) + " or " + str(arch_path),
                )
        return util_path

    def exec(self):
        util_path = self._get_util_path()
        check_call([which("python3"), "-m", util_path] + self.args, env=self.env)
