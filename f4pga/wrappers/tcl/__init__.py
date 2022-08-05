#!/usr/bin/env python3
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
#
# TCL scripts moved from f4pga-arch-defs

from pathlib import Path
from f4pga import FPGA_FAM

ROOT = Path(__file__).resolve().parent

ARCHS = {
    'xc7': [
        'artix7',
        'artix7_100t',
        'artix7_200t',
        'zynq7',
        'zynq7_z020',
        'spartan7'
    ],
    'eos-s3': [
        'ql-s3',
        'pp3'
    ]
}


def get_script_path(arg, arch = None):
    if arch is None:
        arch = FPGA_FAM
    for key, val in ARCHS.items():
        if arch in val:
            arch = key
            break
    if arch not in [
        'xc7',
        'eos-s3',
        'qlf_k4n8',
        'ice40'
    ]:
        raise(Exception(f"Unsupported arch <{arch}>!"))
    if arg not in ['synth', 'conv']:
        raise Exception(f'Unknown tcl wrapper <{arg}>!')
    return ROOT / arch / f'{arg}.f4pga.tcl'
