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
Rename (ie. change) dependencies and values of a module. This module wraps another,
module whoose name is specified in `params.module` and changes the names of the
dependencies and values it relies on. The parmeters for the wrapped module can be
specified through `params.params`. dict. There are three mapping for the names:
* `params.rename_takes` - mapping for inputs ("takes")
* `params.rename_produces` - mapping for outputs ("products")
* `params.rename_values` - mapping for values
Keys represent the names visible to the wrpped module and values represent the
names visible to the modules outside.
Not specifying a mapping for a given entry will leave it with its original name.

---------------

Accepted module parameters:
* `module` (string, required)
* `params` (dict[string -> any], optional)
* `rename_takes` (dict[string -> string], optional)
* `rename_produces` (dict[string -> string], optional)
* `rename_values` (dict[string -> string], optional)

"""

from argparse import Namespace
from types import SimpleNamespace

from f4pga.flows.common import decompose_depname, resolve_modstr, with_qualifier
from f4pga.flows.module import Module, ModuleContext
from f4pga.flows.runner import get_module


def _switch_keys(d: "dict[str, ]", renames: "dict[str, str]") -> "dict[str, ]":
    newd = {}
    for k, v in d.items():
        r = renames.get(k)
        if r is not None:
            newd[r] = v
        else:
            newd[k] = v
    return newd


def _switchback_attrs(d: Namespace, renames: "dict[str, str]") -> SimpleNamespace:
    newn = SimpleNamespace()
    for k, v in vars(d).items():
        setattr(newn, k, v)
    for k, r in renames.items():
        if hasattr(newn, r):
            v = getattr(newn, r)
            delattr(newn, r)
            setattr(newn, k, v)
    return newn


def _switch_entries(l: "list[str]", renames: "dict[str, str]") -> "list[str]":
    newl = []
    for e in l:
        r = renames.get(e)
        if r is not None:
            _, q = decompose_depname(e)
            newl.append(with_qualifier(r, q))
        else:
            newl.append(r if r is not None else e)
    return newl


def _or_empty_dict(d: "dict | None"):
    return d if d is not None else {}


class IORenameModule(Module):
    module: Module
    rename_takes: "dict[str, str]"
    rename_produces: "dict[str, str]"
    rename_values: "dict[str, str]"

    def map_io(self, ctx: ModuleContext):
        newctx = ctx.shallow_copy()
        newctx.takes = _switchback_attrs(ctx.takes, self.rename_takes)
        newctx.values = _switchback_attrs(ctx.values, self.rename_values)
        r = self.module.map_io(newctx)
        return _switch_keys(r, self.rename_produces)

    def execute(self, ctx: ModuleContext):
        newctx = ctx.shallow_copy()
        newctx.takes = _switchback_attrs(ctx.takes, self.rename_takes)
        newctx.values = _switchback_attrs(ctx.values, self.rename_values)
        newctx.outputs = _switchback_attrs(ctx.produces, self.rename_produces)
        print(newctx.takes)
        return self.module.execute(newctx)

    def __init__(self, params, r_env, instance_name):
        super().__init__(params, r_env, instance_name)

        mod_path = resolve_modstr(params["module"])
        module_class = get_module(mod_path)
        module: Module = module_class(params.get("params"))

        self.rename_takes = _or_empty_dict(params.get("rename_takes"))
        self.rename_produces = _or_empty_dict(params.get("rename_produces"))
        self.rename_values = _or_empty_dict(params.get("rename_values"))

        self.module = module
        self.no_of_phases = module.no_of_phases
        self.takes = _switch_entries(module.takes, self.rename_takes)
        self.produces = _switch_entries(module.produces, self.rename_produces)
        self.values = _switch_entries(module.values, self.rename_values)
        if hasattr(module, "prod_meta"):
            self.prod_meta = _switch_keys(module.prod_meta, self.rename_produces)


ModuleClass = IORenameModule
