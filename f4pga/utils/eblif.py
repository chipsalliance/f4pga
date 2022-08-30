#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright (C) 2019-2022 F4PGA Authors
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

# Top level keywords defining the begin of a cell definition.
top_level = [
    "model",
    "inputs",
    "outputs",
    "names",
    "latch",
    "subckt",
]

# Keywords defining cell attributes / parameters. Those can be specified for
# each cell multiple times. Parameter names and values are stored in a dict
# under the parsed blif data.
#
# For example: the construct ".param MODE SYNC" will add to the dict under
# the key "param" entry "MODE":"SYNC".
#
sub_level = [
    "attr",
    "param",
]


def parse_blif(f):
    current = None

    data = {}

    def add(d):
        if d["type"] not in data:
            data[d["type"]] = []
        data[d["type"]].append(d)

    current = None
    for oline in f:
        line = oline
        if "#" in line:
            line = line[: line.find("#")]
        line = line.strip()
        if not line:
            continue

        if line.startswith("."):
            args = line.split(" ", maxsplit=1)
            if len(args) < 2:
                args.append("")

            ctype = args.pop(0)
            assert ctype.startswith("."), ctype
            ctype = ctype[1:]

            if ctype in top_level:
                if current:
                    add(current)
                current = {
                    "type": ctype,
                    "args": args[-1].split(),
                    "data": [],
                }
            elif ctype in sub_level:
                if ctype not in current:
                    current[ctype] = {}
                key, value = args[-1].split(maxsplit=1)
                current[ctype][key] = value
            else:
                current[ctype] = args[-1].split()
            continue
        current["data"].append(line.strip().split())

    if current:
        add(current)

    assert len(data["inputs"]) == 1
    data["inputs"] = data["inputs"][0]
    assert len(data["outputs"]) == 1
    data["outputs"] = data["outputs"][0]
    return data
