#!/usr/bin/env python3
#
# -*- coding: utf-8 -*-
#
# Copyright (C) 2020-2022 F4PGA Authors.
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

from pathlib import Path

from setuptools import setup as setuptools_setup

from os import environ
F4PGA_FAM = environ.get('F4PGA_FAM', 'xc7')


packagePath = Path(__file__).resolve().parent

sf = "symbiflow"
shwrappers = "f4pga.wrappers.sh.__init__"

wrapper_entrypoints = [
    f"{sf}_generate_constraints = {shwrappers}:generate_constraints",
    f"{sf}_pack = {shwrappers}:pack",
    f"{sf}_place = {shwrappers}:place",
    f"{sf}_route = {shwrappers}:route",
    f"{sf}_synth = {shwrappers}:synth",
    f"{sf}_write_bitstream = {shwrappers}:write_bitstream",
    f"{sf}_write_fasm = {shwrappers}:write_fasm",
] if F4PGA_FAM == 'xc7' else [
    f"{sf}_pack = {shwrappers}:pack",
    f"{sf}_place = {shwrappers}:place",
    f"{sf}_route = {shwrappers}:route",
    f"{sf}_write_fasm = {shwrappers}:write_fasm",
]

setuptools_setup(
    name=packagePath.name,
    version="0.0.0",
    license="Apache-2.0",
    author="F4PGA Authors",
    description="F4PGA.",
    url="https://github.com/chipsalliance/f4pga",
    packages=[
        "f4pga.wrappers.sh",
    ],
    package_dir={"f4pga": "."},
    package_data={
        'f4pga.wrappers.sh': ['xc7/*.f4pga.sh', 'quicklogic/*.f4pga.sh']
    },
    classifiers=[],
    python_requires='>=3.6',
    entry_points={
        "console_scripts": wrapper_entrypoints
    },
)
