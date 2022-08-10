#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright (C) 2020-2022 F4PGA Authors.
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

from os import environ
from pytest import mark
from sys import stdout, stderr

from subprocess import check_call


wrappers = [
    'symbiflow_generate_constraints',
    'symbiflow_pack',
    'symbiflow_place',
    'symbiflow_route',
    'symbiflow_synth',
    'symbiflow_write_bitstream',
    'symbiflow_write_fasm',
    'vpr_common',
    'symbiflow_analysis',
    'symbiflow_repack',
    'symbiflow_generate_bitstream',
    'symbiflow_generate_libfile',
    'ql_symbiflow'
]

@mark.xfail
@mark.parametrize(
    "wrapper",
    wrappers
)
def test_shell_wrapper(wrapper):
    print(f"\n::group::Test {wrapper}")
    stdout.flush()
    stderr.flush()
    try:
        check_call(f"{wrapper}")
    finally:
        print("\n::endgroup::")

@mark.xfail
@mark.parametrize(
    "wrapper",
    wrappers
)
def test_shell_wrapper_without_F4PGA_INSTALL_DIR(wrapper):
    test_environ = environ.copy()
    del test_environ['F4PGA_INSTALL_DIR']

    print(f"\n::group::Test {wrapper}")
    stdout.flush()
    stderr.flush()
    try:
        check_call(f"{wrapper}", env=test_environ)
    finally:
        print("\n::endgroup::")
