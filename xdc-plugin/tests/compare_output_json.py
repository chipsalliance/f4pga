#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright (C) 2020-2021  The SymbiFlow Authors.
#
# Use of this source code is governed by a ISC-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/ISC
#
# SPDX-License-Identifier:ISC

"""

This script extracts the top module cells and their corresponding parameters
from json files produced by Yosys.
The return code of this script is used to check if the output is equivalent.
"""

import sys
import json
import argparse

parameters = ["IOSTANDARD", "DRIVE", "SLEW", "IN_TERM", "IO_LOC_PAIRS"]

def read_cells(json_file):
    with open(json_file) as f:
        data = json.load(f)
    f.close()
    cells = data['modules']['top']['cells']
    cells_parameters = dict()
    for cell, opts in cells.items():
        attributes = opts['parameters']
        if len(attributes.keys()):
            if any([x in parameters for x in attributes.keys()]):
                cells_parameters[cell] = attributes
    return cells_parameters


def main(args):
    cells = read_cells(args.json)
    if args.update:
        with open(args.golden, 'w') as f:
            json.dump(cells, f, indent=2)
    else:
        with open(args.golden) as f:
            cells_golden = json.load(f)
            if cells == cells_golden:
                exit(0)
            else:
                print(json.dumps(cells, indent=4))
                print("VS")
                print(json.dumps(cells_golden, indent=4))
                exit(1)
    f.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--json', help = 'JSON to compare', required = True)
    parser.add_argument('--golden', help = 'Golden JSON file', required = True)
    parser.add_argument('--update', action = 'store_true', help = 'Update golden reference')
    args = parser.parse_args()
    main(args)
