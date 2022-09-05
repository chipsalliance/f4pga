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
This script reads Verilog compile options string from stdin and outputs a
series of Yosys commands that implement them to stdout.
"""

import os
import sys
import shlex


def eprint(*args, **kwargs):
    """
    Like print() but to stderr
    """
    print(*args, file=sys.stderr, **kwargs)


def parse_options(lines, opts=None):
    """
    Parses compile options
    """

    # Remove "#" comments and C/C++ style "//" comments, remove blank lines,
    # join all remaining ones into a single string
    opt_string = ""
    for line in lines:

        # Remove comments
        pos = line.find("#")
        if pos != -1:
            line = line[:pos]

        pos = line.find("//")
        if pos != -1:
            line = line[:pos]

        # Append
        line = line.strip()
        if line:
            opt_string += line + " "

    # Remove all C/C++ style "/* ... */" comments
    while True:

        # Find beginning of a block comment. Finish if none is found
        p0 = opt_string.find("/*")
        if p0 == -1:
            break

        # Find ending of a block comments. Throw an error if none is found
        p1 = opt_string.find("*/", p0 + 2)
        if p1 == -1:
            eprint("ERROR: Unbalanced block comment!")
            exit(-1)

        # Remove the comment
        opt_string = opt_string[:p0] + opt_string[p1 + 2 :]

    # Initialize options if not given
    if opts is None:
        opts = {"incdir": set(), "libdir": set(), "libext": set(), "defines": {}}

    # Scan and process options
    parts = iter(shlex.split(opt_string))
    while True:

        # Get the option
        try:
            opt = next(parts)
        except StopIteration:
            break

        # A file containing options
        if opt == "-f":
            try:
                arg = next(parts)
            except StopIteration:
                eprint("ERROR: Missing file name for '-f'")
                exit(-1)

            # Open and read the file, recurse
            if not os.path.isfile(arg):
                eprint("ERROR: File '{}' does not exist".format(arg))
                exit(-1)

            with open(arg, "r") as fp:
                lines = fp.readlines()

            parse_options(lines, opts)

        # Verilog library directory
        elif opt == "-y":
            try:
                arg = next(parts)
            except StopIteration:
                eprint("ERROR: Missing directory name for '-y'")
                exit(-1)

            if not os.path.isdir(arg):
                eprint("ERROR: Directory '{}' does not exist".format(arg))
                exit(-1)

            opts["libdir"].add(arg)

        # Library file extensions
        elif opt.startswith("+libext+"):
            args = opt.strip().split("+")
            if len(args) < 2:
                eprint("ERROR: Missing file extensions(s) for '+libext+'")
                exit(-1)

            opts["libext"] |= set(args[2:])

        # Verilog include directory
        elif opt.startswith("+incdir+"):
            args = opt.strip().split("+")
            if len(args) < 2:
                eprint("ERROR: Missing file name(s) for '+incdir+'")
                exit(-1)

            opts["incdir"] |= set(args[2:])

        # Verilog defines
        elif opt.startswith("+define+"):
            args = opt.strip().split("+")
            if len(args) < 2:
                eprint("ERROR: Malformed '+define+' directive")
                exit(-1)

            # Parse defines. They may or may not have values
            for arg in args[2:]:
                if "=" in arg:
                    key, value = arg.split("=")
                else:
                    key, value = arg, None

                if key in opts["defines"]:
                    eprint("ERROR: Macro '{}' defined twice!".format(key))
                opts["defines"][key] = value

    return opts


def quote(s):
    """
    Quotes a string if it needs it
    """
    if " " in s:
        return '"' + s + '"'
    else:
        return s


def translate_options(opts):
    """
    Translates the given options into Yosys commands
    """

    commands = []

    # Include directories
    for incdir in opts["incdir"]:
        cmd = "verilog_defaults -add -I{}".format(quote(incdir))
        commands.append(cmd)

    # Macro defines
    for key, val in opts["defines"].items():
        if val is not None:
            cmd = "verilog_defaults -add -D{}={}".format(key, val)
        else:
            cmd = "verilog_defaults -add -D{}".format(key)
        commands.append(cmd)

    # Since Yosys does not automatically search for an unknown module in
    # verilog files make it read all library files upfront. Do this by
    # searching for files with extensions provided with "+libext+" in
    # paths privided by "-y".
    libext = opts["libext"] | {"v"}

    for libdir in opts["libdir"]:
        for f in os.listdir(libdir):
            _, ext = os.path.splitext(f)
            if ext.replace(".", "") in libext:
                fname = os.path.join(libdir, f)
                cmd = "read_verilog {}".format(quote(fname))
                commands.append(cmd)

    return commands


# =============================================================================

if __name__ == "__main__":

    # Read lines from stdin, parse options
    lines = sys.stdin.readlines()
    opts = parse_options(lines)

    # Translate parsed options to Yosys commands and output them
    cmds = translate_options(opts)
    for cmd in cmds:
        print(cmd)
