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

from pathlib import Path
from textwrap import indent

from yaml import load as yaml_load, Loader as yaml_loader


ROOT = Path(__file__).resolve().parent


def repo_url(repo, value):
    ref = value
    if '@' in value:
       parts = value.split('@')
       repo = parts[0]
       ref = parts[1]
    return f'https://github.com/{repo}/commit/{ref}'


def generate_changes_inc():

   with open(ROOT / "changes.yml") as data_file:
       changes_yml = yaml_load(data_file, yaml_loader)

   with (ROOT / "development/changes.inc").open("w", encoding="utf-8") as wfptr:
       revs = sorted(changes_yml.keys())

       wfptr.write('''
Tested environments
===================\n
''')

       for item in reversed(revs[1:]):

           f4pga = changes_yml[revs[item]]['f4pga']
           examples = changes_yml[revs[item]]['examples']

           arch_defs = changes_yml[revs[item]]['arch-defs'].split('@')
           arch_defs_timestamp = arch_defs[0]
           arch_defs_hash = arch_defs[1]

           tarballs = changes_yml[revs[item]]['tarballs']
           eos_s3 = '    '.join([f"* ``{item}``\n" for item in tarballs['eos-s3']])
           xc7 = '    '.join([f"* ``{item}``\n" for item in tarballs['xc7']])

           wfptr.write(f'''
{revs[item]}
---

.. NOTE::
{indent(changes_yml[revs[item]]['description'], '  ')}

* Examples: `{examples} <{repo_url("chipsalliance/f4pga-examples", examples)}>`__
* CLI: `{f4pga} <{repo_url("chipsalliance/f4pga",f4pga)}>`__
* Architecture Definitions: {arch_defs[0]} @ `{arch_defs[1]} <https://github.com/SymbiFlow/f4pga-arch-defs/commit/{arch_defs[1]}>`__

  * xc7

    {xc7}
  * eos-s3

    {eos_s3}
''')

       wfptr.write('''
Future work
===========\n
''')
       wfptr.write(changes_yml[revs[0]]['future-work'])
