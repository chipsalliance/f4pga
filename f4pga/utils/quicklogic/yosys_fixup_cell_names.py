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
This is an utility script that performs cell instance renaming in a design in
Yosys JSON format. Cell instance names containing dots are altered so that
all dots are replaced with underscores.
"""

import argparse
import json


def fixup_cell_names(design):
    """
    Scans Yosys' JSON data structure and replaces cell instance names that
    contains dots in names with other character.
    """

    # Process modules
    modules = design["modules"]
    for mod_name, mod_data in modules.items():
        print(mod_name)

        # Process cells
        cells = mod_data["cells"]
        for cell_name in list(cells.keys()):

            # Fixup name
            if "." in cell_name:
                new_name = cell_name.replace(".", "_")
                assert new_name not in cells, new_name

                cells[new_name] = cells[cell_name]
                del cells[cell_name]

    return design


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("i", type=str, help="Yosys JSON in")
    parser.add_argument("o", type=str, help="Yosys JSON out")

    args = parser.parse_args()

    with open(args.i, "r") as fp:
        design = fixup_cell_names(json.load(fp))

    with open(args.o, "w") as fp:
        json.dump(design, fp, indent=2)


if __name__ == "__main__":
    main()
