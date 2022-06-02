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

from pathlib import Path
from os import environ, listdir as os_listdir
from sys import argv as sys_argv
from argparse import Namespace
from shutil import move as sh_mv
from subprocess import run
from re import match as re_match, finditer as re_finditer


def decompose_depname(name: str):
    spec = 'req'
    specchar = name[len(name) - 1]
    if specchar == '?':
        spec = 'maybe'
    elif specchar == '!':
        spec = 'demand'
    if spec != 'req':
        name = name[:len(name) - 1]
    return name, spec


def with_qualifier(name: str, q: str) -> str:
    if q == 'req':
        return decompose_depname(name)[0]
    if q == 'maybe':
        return decompose_depname(name)[0] + '?'
    if q == 'demand':
        return decompose_depname(name)[0] + '!'


_sfbuild_module_collection_name_to_path = {}


def scan_modules(mypath: str):
    global _sfbuild_module_collection_name_to_path

    sfbuild_home = mypath
    sfbuild_home_dirs = os_listdir(sfbuild_home)
    sfbuild_module_dirs = \
        [dir for dir in sfbuild_home_dirs if re_match('.*_modules$', dir)]
    _sfbuild_module_collection_name_to_path = dict([
            (
                re_match('(.*)_modules$', moddir).groups()[0],
                str(Path(sfbuild_home) / moddir)
            )
            for moddir in sfbuild_module_dirs
        ])


def resolve_modstr(modstr: str):
    """
    Resolves module location from modulestr.
    """
    sl = modstr.split(':')
    if len(sl) > 2:
        raise Exception('Incorrect module sysntax. Expected one \':\' or one \'::\'')
    if len(sl) < 2:
        return modstr
    collection_name = sl[0]
    module_filename = sl[1] + '.py'

    col_path = _sfbuild_module_collection_name_to_path.get(collection_name)
    if not col_path:
        fatal(-1, f'Module collection {collection_name} does not exist')
    return str(Path(col_path) / module_filename)


def deep(fun):
    """
    Create a recursive string transform function for 'str | list | dict', i.e a dependency.
    """
    def d(paths, *args, **kwargs):
        if type(paths) is str:
            return fun(paths)
        elif type(paths) is list:
            return [d(p) for p in paths];
        elif type(paths) is dict:
            return dict([(k, d(p)) for k, p in paths.items()])
    return d


class VprArgs:
    """
    Represents argument list for VPR (Versatile Place and Route).
    """

    arch_dir: str
    arch_def: str
    lookahead: str
    rr_graph: str
    place_delay: str
    device_name: str
    eblif: str
    optional: list

    def __init__(self, share: str, eblif, values: Namespace,
                 sdc_file: 'str | None' = None,
                 vpr_extra_opts: 'list | None' = None):
        self.arch_dir = str(Path(share) / 'arch')
        self.arch_def = values.arch_def
        self.lookahead = values.rr_graph_lookahead_bin
        self.rr_graph = values.rr_graph_real_bin
        self.place_delay = values.vpr_place_delay
        self.device_name = values.vpr_grid_layout_name
        self.eblif = str(Path(eblif).resolve())
        if values.vpr_options is not None:
            self.optional = options_dict_to_list(values.vpr_options)
        else:
            self.optional = []
        if vpr_extra_opts is not None:
            self.optional += vpr_extra_opts
        if sdc_file is not None:
            self.optional += ['--sdc_file', sdc_file]


class SubprocessException(Exception):
    return_code: int


def sub(*args, env=None, cwd=None):
    """
    Execute subroutine.
    """

    out = run(args, capture_output=True, env=env, cwd=cwd)
    if out.returncode != 0:
        print(f'[ERROR]: {args[0]} non-zero return code.\n'
              f'stderr:\n{out.stderr.decode()}\n\n'
              )
        exit(out.returncode)
    return out.stdout


def vpr(mode: str, vprargs: VprArgs, cwd=None):
    """
    Execute `vpr`.
    """

    modeargs = []
    if mode == 'pack':
        modeargs = ['--pack']
    elif mode == 'place':
        modeargs = ['--place']
    elif mode == 'route':
        modeargs = ['--route']

    return sub(*([
        'vpr',
        vprargs.arch_def,
        vprargs.eblif,
        '--device', vprargs.device_name,
        '--read_rr_graph', vprargs.rr_graph,
        '--read_router_lookahead', vprargs.lookahead,
        '--read_placement_delay_lookup', vprargs.place_delay
    ] + modeargs + vprargs.optional), cwd=cwd)



_vpr_specific_values = [
    'arch_def',
    'rr_graph_lookahead_bin',
    'rr_graph_real_bin',
    'vpr_place_delay',
    'vpr_grid_layout_name',
    'vpr_options?'
]


def vpr_specific_values():
    global _vpr_specific_values
    return _vpr_specific_values


def options_dict_to_list(opt_dict: dict):
    """
    Converts a dictionary of named options for CLI program to a list.
    Example: { "option_name": "value" } -> [ "--option_name", "value" ]
    """

    opts = []
    for key, val in opt_dict.items():
        opts.append('--' + key)
        if not(type(val) is list and val == []):
            opts.append(str(val))
    return opts


def noisy_warnings(device):
    """
    Emit some noisy warnings.
    """
    environ['OUR_NOISY_WARNINGS'] = f'noisy_warnings-{device}_pack.log'


def my_path():
    """
    Get current PWD.
    """
    return str(Path(sys_argv[0]).resolve().parent)


def save_vpr_log(filename, build_dir=''):
    """
    Save VPR logic (moves the default output file into a desired path).
    """
    sh_mv(str(Path(build_dir) / 'vpr_stdout.log'), filename)


def fatal(code, message):
    """
    Print a message informing about an error that has occured and terminate program with a given return code.
    """
    raise(Exception(f'[FATAL ERROR]: {message}'))
    exit(code)


class ResolutionEnv:
    """
    ResolutionEnv is used to hold onto mappings for variables used in flow and perform text substitutions using those
    variables.
    Variables can be referred in any "resolvable" string using the following syntax: 'Some static text ${variable_name}'.
    The '${variable_name}' part will be replaced by the value associated with name 'variable_name', is such mapping
    exists.

    values: dict
    """

    def __init__(self, values={}):
        self.values = values

    def __copy__(self):
        return ResolutionEnv(self.values.copy())

    def resolve(self, s, final=False):
        """
        Perform resolution on `s`.
        `s` can be a `str`, a `dict` with arbitrary keys and resolvable values, or a `list` of resolvable values.
        final=True - resolve any unknown variables into ''
        This is a hack and probably should be removed in the future
        """

        if type(s) is str:
            match_list = list(re_finditer('\$\{([^${}]*)\}', s))
            # Assumption: re_finditer finds matches in a left-to-right order
            match_list.reverse()
            for match in match_list:
                match_str = match.group(1)
                match_str = match_str.replace('?', '')
                v = self.values.get(match_str)
                if not v:
                    if final:
                        v = ''
                    else:
                        continue
                span = match.span()
                if type(v) is str:
                    s = s[:span[0]] + v + s[span[1]:]
                elif type(v) is list: # Assume it's a list of strings
                    ns = list([s[:span[0]] + ve + s[span[1]:] for ve in v])
                    s = ns

        elif type(s) is list:
            s = list(map(self.resolve, s))
        elif type(s) is dict:
            s = dict([(k, self.resolve(v)) for k, v in s.items()])
        return s

    def add_values(self, values: dict):
        """
        Add mappings from `values`.
        """
        for k, v in values.items():
            self.values[k] = self.resolve(v)


verbosity_level = 0


def sfprint(verbosity: int, *args):
    """
    Print with regards to currently set verbosity level.
    """
    global verbosity_level
    if verbosity <= verbosity_level:
        print(*args)


def set_verbosity_level(level: int):
    global verbosity_level
    verbosity_level = level


def get_verbosity_level() -> int:
    global verbosity_level
    return verbosity_level
