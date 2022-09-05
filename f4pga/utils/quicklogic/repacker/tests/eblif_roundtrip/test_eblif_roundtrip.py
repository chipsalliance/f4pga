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
import os
import sys
import tempfile

sys.path.append(os.path.join(os.path.dirname(__file__), "..", ".."))
from eblif_netlist import Eblif  # noqa: E402

# =============================================================================


def test_netlist_roundtrip():

    basedir = os.path.dirname(__file__)
    golden_file = os.path.join(basedir, "netlist.golden.eblif")

    # Load and parse the EBLIF file
    eblif = Eblif.from_file(golden_file)

    with tempfile.TemporaryDirectory() as tempdir:

        # Write the EBLIF back
        output_file = os.path.join(tempdir, "netlist.output.eblif")
        eblif.to_file(output_file)

        # Compare the two files
        with open(golden_file, "r") as fp:
            golden_data = fp.read().rstrip()
        with open(output_file, "r") as fp:
            output_data = fp.read().rstrip()

        assert golden_data == output_data
