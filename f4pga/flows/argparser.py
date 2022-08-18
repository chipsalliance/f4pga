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

from argparse import ArgumentParser, Namespace
from re import finditer as re_finditer


def _add_flow_arg(parser: ArgumentParser):
    parser.add_argument(
        '-f',
        '--flow',
        metavar='flow_path',
        type=str,
        help='Path to flow definition file'
    )


def _setup_build_parser(parser: ArgumentParser):
    _add_flow_arg(parser)

    parser.add_argument(
        '-t',
        '--target',
        metavar='target_name',
        type=str,
        help='Perform stages necessary to acquire target'
    )

    parser.add_argument(
        '-P',
        '--pretend',
        action='store_true',
        help='Show dependency resolution without executing flow'
    )

    parser.add_argument(
        '-i',
        '--info',
        action='store_true',
        help='Display info about available targets'
    )

    parser.add_argument(
        '-c',
        '--nocache',
        action='store_true',
        help='Ignore caching and rebuild everything up to the target.'
    )

    parser.add_argument(
        '-S',
        '--stageinfo',
        nargs=1,
        metavar='stage_name',
        help='Display info about stage'
    )

    parser.add_argument(
        '-p',
        '--part',
        metavar='part_name',
        help='Name of the target chip'
    )

    parser.add_argument(
        '--dep',
        '-D',
        action='append',
        default=[]
    )

    parser.add_argument(
        '--val',
        '-V',
        action='append',
        default=[]
    )

def _setup_show_dep_parser(parser: ArgumentParser):
    parser.add_argument(
        '-p',
        '--part',
        metavar='part_name',
        type=str,
        help='Name of the part (use to display part-specific values.)'
    )

    parser.add_argument(
        '-s',
        '--stage',
        metavar='stage_name',
        type=str,
        help='Name of the stage (use if you want to set the value only for that stage). Requires `-p`.'
    )

    _add_flow_arg(parser)


def setup_argparser():
    """
    Set up argument parser for the program.
    """
    parser = ArgumentParser(description='F4PGA Build System')

    parser.add_argument(
        '-v',
        '--verbose',
        action='count',
        default=0
    )

    parser.add_argument(
        '-s',
        '--silent',
        action='store_true'
    )

    subparsers = parser.add_subparsers(dest='command')
    _setup_build_parser(subparsers.add_parser('build'))
    show_dep = subparsers.add_parser('showd', description='Show the value(s) assigned to a dependency')
    _setup_show_dep_parser(show_dep)

    return parser


def _parse_depval(depvalstr: str):
    """
    Parse a dependency or value definition in form of:
    optional_stage_name.value_or_dependency_name=value
    See `_parse_cli_value` for detail on how to pass different kinds of values.
    """

    d = { 'name': None, 'stage': None, 'value': None }

    splitted = list(_unescaped_separated('=', depvalstr))

    if len(splitted) != 2:
        raise Exception('Too many components')

    pathstr = splitted[0]
    valstr = splitted[1]

    path_components = pathstr.split('.')
    if len(path_components) < 1:
        raise Exception('Missing value')
    d['name'] = path_components.pop(len(path_components) - 1)
    if len(path_components) > 0:
        d['stage'] = path_components.pop(0)
    if len(path_components) > 0:
        raise Exception('Too many path components')

    d['value'] = _parse_cli_value(valstr)

    return d


def _unescaped_matches(regexp: str, s: str, escape_chr='\\'):
    """
    Find all occurences of a pattern in a string that contains escape sequences.
    Yields pairs of starting and ending indices of the pattern.
    """

    noescapes = ''

    # We remove all escape sequnces from a string, so it will match only with
    # unescaped characters, but to map the results back to the string containing the
    # escape sequences, we need to track the offsets by which the characters were
    # shifted.
    offsets = []
    offset = 0
    for sl in s.split(escape_chr):
        if len(sl) <= 1:
            continue
        noescape = sl[(1 if offset != 0 else 0):]
        for _ in noescape:
            offsets.append(offset)
        offset += 2
        noescapes += noescape

    iter = re_finditer(regexp, noescapes)

    for m in iter:
        start = m.start()
        end = m.end()
        off1 = start + offsets[start]
        off2 = end + offsets[end]
        yield off1, off2


def _unescaped_separated(regexp: str, s: str, escape_chr='\\'):
    """
    Yields substrings of a string that contains escape sequences.
    """

    last_end = 0
    for start, end in _unescaped_matches(regexp, s, escape_chr=escape_chr):
        yield s[last_end:start]
        last_end = end
    if last_end < len(s):
        yield s[last_end:]
    else:
        yield ''


def _parse_cli_value(s: str):
    """
    Parse a value/dependency passed to CLI
    CLI values are generated by the following non-contextual grammar:

        S -> :str: (string/number value)
        S -> [I]
        S -> {D}
        I -> I,I
        I -> S
        D -> D,D
        D -> K:S
        K -> :str:

        Starting symbol = S
        Terminal symbols: '[', ']', '{', '}', ':', ,',', :str:
            (:str: represents any string where terminals are escaped)

    TODO: The current implementation of my parser is crippled and is
          not able to parse nested structures. Currently there is no real use
          case for having nested structures as values, so it's kinda fine atm.
    """

    if len(s) == 0:
        return ''

    # List
    if s[0] == '[':
        if len(s) < 2 or s[len(s)-1] != ']':
            raise Exception('Missing \']\' delimiter')
        inner = s[1:(len(s)-1)]
        if inner == '':
            return []
        return [_parse_cli_value(v) for v in _unescaped_separated(',', inner)]

    # Dictionary
    if s[0] == '{':
        if len(s) < 2 or s[len(s)-1] != '}':
            raise Exception('Missing \'}\' delimiter')
        d = {}
        inner = s[1:(len(s)-1)]
        if inner == '':
            return {}
        for kv in _unescaped_separated(',', inner):
            k_v = list(_unescaped_separated(':', kv))
            if len(k_v) < 2:
                raise Exception('Missing value in dictionary entry')
            if len(k_v) > 2:
                raise Exception('Unexpected \':\' token')
            key = k_v[0]
            value =  _parse_cli_value(k_v[1])
            d[key] = value

        return d

    # Bool hack
    if s == '\\True':
        return True
    if s == '\\False':
        return False

    # Number hack
    if len(s) >= 3 and s[0:1] == '\\N':
        return int(s[2:])

    # String
    return s.replace('\\', '')


def get_cli_flow_config(args: Namespace, part: str):
    def create_defdict():
        return {
            'dependencies': {},
            'values': {},
        }

    part_flow_config = create_defdict()

    def add_entries(arglist: 'list[str]', dict_name: str):
        for value_def in (_parse_depval(cliv) for cliv in arglist):
            stage = value_def['stage']
            if stage is None:
                part_flow_config[dict_name][value_def['name']] = \
                    value_def['value']
            else:
                if part_flow_config.get(stage) is None:
                    part_flow_config[stage] = create_defdict()
                part_flow_config[stage][dict_name][value_def['name']] = \
                    value_def['value']

    add_entries(args.dep, 'dependencies')
    add_entries(args.val, 'values')

    return { part: part_flow_config }
