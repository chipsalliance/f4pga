#!/usr/bin/python3

# Symbiflow Stage Module

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

# ----------------------------------------------------------------------------- #

from sf_common import *
from sf_module import *
from sf_module_runner import get_module

# ----------------------------------------------------------------------------- #

def _switch_keys(d: 'dict[str, ]', renames: 'dict[str, str]') -> 'dict[str, ]':
    newd = {}
    for k, v in d.items():
        r = renames.get(k)
        if r is not None:
            newd[r] = v
        else:
            newd[k] = v
    return newd

def _switchback_attrs(d: Namespace, renames: 'dict[str, str]') -> SimpleNamespace:
    newn = SimpleNamespace()
    for k, v in vars(d).items():
        setattr(newn, k, v)
    for k, r in renames.items():
        if hasattr(newn, r):
            v = getattr(newn, r)
            delattr(newn, r)
            setattr(newn, k, v)
    return newn

def _switch_entries(l: 'list[str]', renames: 'dict[str, str]') -> 'list[str]':
    newl = []
    for e in l:
        r = renames.get(e)
        if r is not None:
            _, q = decompose_depname(e)
            newl.append(with_qualifier(r, q))
        else:
            newl.append(r if r is not None else e)
    return newl
    
def _generate_stage_name(name: str):
    return f'{name}-io_renamed'

def _or_empty_dict(d: 'dict | None'):
    return d if d is not None else {}

class IORenameModule(Module):
    module: Module
    rename_takes: 'dict[str, str]'
    rename_produces: 'dict[str, str]'
    rename_values: 'dict[str, str]'

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
    
    def __init__(self, params):
        mod_path = resolve_modstr(params["module"])
        module_class = get_module(mod_path)
        module: Module = module_class(params.get("params"))

        self.rename_takes = _or_empty_dict(params.get("rename_takes"))
        self.rename_produces = _or_empty_dict(params.get("rename_produces"))
        self.rename_values = _or_empty_dict(params.get("rename_values"))

        self.module = module
        self.name = _generate_stage_name(module.name)
        self.no_of_phases = module.no_of_phases
        self.takes = _switch_entries(module.takes, self.rename_takes)
        self.produces = _switch_entries(module.produces, self.rename_produces)
        self.values = _switch_entries(module.values, self.rename_values)
        if hasattr(module, 'prod_meta'):
            self.prod_meta = _switch_keys(module.prod_meta, self.rename_produces)

ModuleClass = IORenameModule