#!/usr/bin/env python3
"""

This script extracts the top module cells and their corresponding parameters
from json files produced by Yosys.
The return code of this script is used to check if the output is equivalent.
"""

import sys
import json

def read_cells(json_file):
    with open(json_file) as f:
        data = json.load(f)
    f.close()
    cells = data['modules']['top']['cells']
    cells_parameters = dict()
    for cell, opts in cells.items():
        cells_parameters[cell] = opts['parameters']
    return cells_parameters


def main():
    if len(sys.argv) < 3:
        print("Incorrect number of arguments")
        exit(1)
    cells1 = read_cells(sys.argv[1])
    cells2 = read_cells(sys.argv[2])
    if cells1 == cells2:
        exit(0)
    else:
        exit(1)

if __name__ == "__main__":
    main()
