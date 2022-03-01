#!/usr/bin/python3

# Symbiflow Stage Module

# ----------------------------------------------------------------------------- #

import os
import shutil
from f4pga.common import *
from f4pga.module import *

# ----------------------------------------------------------------------------- #

def route_place_file(eblif: str):
    return file_noext(eblif) + '.route'

class RouteModule(Module):
    def map_io(self, ctx: ModuleContext):
        return {
            'route': route_place_file(ctx.takes.eblif)
        }

    def execute(self, ctx: ModuleContext):
        build_dir = os.path.dirname(ctx.takes.eblif)

        vpr_options = []
        if ctx.values.vpr_options:
            vpr_options = options_dict_to_list(ctx.values.vpr_options)


        vprargs = VprArgs(ctx.share, ctx.takes.eblif, ctx.values,
                          sdc_file=ctx.takes.sdc)

        yield 'Routing with VPR...'
        vpr('route', vprargs, cwd=build_dir)

        if ctx.is_output_explicit('route'):
            shutil.move(route_place_file(ctx.takes.eblif), ctx.outputs.route)

        yield 'Saving log...'
        save_vpr_log('route.log', build_dir=build_dir)

    def __init__(self, _):
        self.name = 'route'
        self.no_of_phases = 2
        self.takes = [
            'eblif',
            'place',
            'sdc?'
        ]
        self.produces = [ 'route' ]
        self.values = [
            'device',
            'vpr_options?'
        ] + vpr_specific_values()

ModuleClass = RouteModule
