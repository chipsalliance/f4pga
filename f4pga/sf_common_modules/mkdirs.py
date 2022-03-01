#!/usr/bin/python3

# Symbiflow Stage Module

""" This module is used as a helper in a abuild chain to automate creating build
directiores. It' currenty the only parametric module, meaning it can take
user-provided input at an early stage in order todetermine its take/produces
I/O. This allows other repesenting configurable directories, such as a build
directory as dependencies and by doing so, allow the dependency algorithm to
lazily create the directories if they become necessary. """

# ----------------------------------------------------------------------------- #

import os
from f4pga.sf_common import *
from f4pga.sf_module import *

# ----------------------------------------------------------------------------- #

class MkDirsModule(Module):
    deps_to_produce: 'dict[str, str]'

    def map_io(self, ctx: ModuleContext):
        return ctx.r_env.resolve(self.deps_to_produce)

    def execute(self, ctx: ModuleContext):
        outputs = vars(ctx.outputs)
        for _, path in outputs.items():
            yield f'Creating directory {path}...'
            os.makedirs(path, exist_ok=True)

    def __init__(self, params):
        self.name = 'mkdirs'
        self.no_of_phases = len(params) if params else 0
        self.takes = []
        self.produces = list(params.keys()) if params else []
        self.values = []
        self.deps_to_produce = params

ModuleClass = MkDirsModule
