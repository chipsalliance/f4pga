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

from f4pga.module import Module
from f4pga.common import decompose_depname
from colorama import Style

def _get_if_qualifier(deplist: 'list[str]', qualifier: str):
    for dep_name in deplist:
        name, q = decompose_depname(dep_name)
        if q == qualifier:
            yield f'● {Style.BRIGHT}{name}{Style.RESET_ALL}'

def _list_if_qualifier(deplist: 'list[str]', qualifier: str, indent: int = 4):
    indent_str = ''.join([' ' for _ in range(0, indent)])
    r = ''

    for line in _get_if_qualifier(deplist, qualifier):
        r += indent_str + line + '\n'

    return r

def get_module_info(module: Module) -> str:
    r= ''
    r += f'Module `{Style.BRIGHT}{module.name}{Style.RESET_ALL}`:\n'
    r += 'Inputs:\n  Required:\n    Dependencies\n'
    r += _list_if_qualifier(module.takes, 'req', indent=6)
    r += '    Values:\n'
    r += _list_if_qualifier(module.values, 'req', indent=6)
    r += '  Optional:\n    Dependencies:\n'
    r += _list_if_qualifier(module.takes, 'maybe', indent=6)
    r += '    Values:\n'
    r += _list_if_qualifier(module.values, 'maybe', indent=6)
    r += 'Outputs:\n  Guaranteed:\n'
    r += _list_if_qualifier(module.produces, 'req', indent=4)
    r += '  On-demand:\n'
    r += _list_if_qualifier(module.produces, 'demand', indent=4)
    r += '  Not guaranteed:\n'
    r += _list_if_qualifier(module.produces, 'maybe', indent= 4)

    return r
