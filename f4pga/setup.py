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

from pathlib import Path
from typing import List
from shutil import which
from subprocess import run

from setuptools import setup as setuptools_setup

from os import environ
FPGA_FAM = environ.get('FPGA_FAM', 'xc7')


packagePath = Path(__file__).resolve().parent
requirementsFile = packagePath / "requirements.txt"


# Read requirements file and add them to package dependency list
def get_requirements(file: Path) -> List[str]:
    requirements = []
    with file.open("r") as fh:
        for line in fh.read().splitlines():
            if line.startswith("#") or line == "":
                continue
            elif line.startswith("-r"):
                # Remove the first word/argument (-r)
                filename = " ".join(line.split(" ")[1:])
                requirements += get_requirements(file.parent / filename)
            elif line.startswith("https"):
                # Convert 'URL#NAME' to 'NAME @ URL'
                splitItems = line.split("#")
                requirements.append("{} @ {}".format(splitItems[1], splitItems[0]))
            else:
                requirements.append(line)
    return requirements


semver = "0.0.0"
version = None

with (packagePath.parent / '.gitcommit').open("r") as rptr:
    sha = rptr.read().strip()
    if sha != '$Format:%h$':
        version = f'{semver}-{sha}'

git = which('git')
if git is not None:
    proc = run(['git', 'rev-parse', 'HEAD'], capture_output=True)
    if proc.returncode == 0:
        version = f'{semver}-{proc.stdout.decode("utf8")[0:8]}'

if version is None:
    version = semver

sf = "symbiflow"
shwrappers = "f4pga.wrappers.sh.__init__"


setuptools_setup(
    name=packagePath.name,
    version=version,
    license="Apache-2.0",
    author="F4PGA Authors",
    description="F4PGA.",
    url="https://github.com/chipsalliance/f4pga",
    packages=[
        "f4pga",
        "f4pga.common_modules",
        "f4pga.wrappers.sh"
    ],
    package_dir={"f4pga": "."},
    package_data={
        'f4pga': [
            '*.json',
            'platforms/*.json'
        ],
        'f4pga.wrappers.sh': [
            'xc7/*.f4pga.sh',
            'quicklogic/*.f4pga.sh'
        ]
    },
    classifiers=[],
    python_requires='>=3.6',
    install_requires=list(set(get_requirements(requirementsFile))),
    entry_points={
        "console_scripts": [
            "f4pga = f4pga.__init__:main",
            f"{sf}_pack = {shwrappers}:pack",
            f"{sf}_place = {shwrappers}:place",
            f"{sf}_route = {shwrappers}:route",
            f"{sf}_synth = {shwrappers}:synth",
            f"{sf}_write_fasm = {shwrappers}:write_fasm"
        ] + (
            [
                f"{sf}_write_bitstream = {shwrappers}:write_bitstream",
            ] if FPGA_FAM == 'xc7' else [
                f"{sf}_analysis = {shwrappers}:analysis",
                f"{sf}_fasm2bels = {shwrappers}:fasm2bels",
                f"{sf}_generate_bitstream = {shwrappers}:generate_bitstream",
                f"{sf}_repack = {shwrappers}:repack",
                f"{sf}_write_binary = {shwrappers}:write_binary",
                f"{sf}_write_bitheader = {shwrappers}:write_bitheader",
                f"{sf}_write_jlink = {shwrappers}:write_jlink",
                f"{sf}_write_openocd = {shwrappers}:write_openocd",
                f"ql_{sf} = {shwrappers}:ql",
                f"vpr_common = {shwrappers}:vpr_common"
            ]
        )
    },
)
