from pathlib import Path
from shutil import move as sh_mv

from f4pga.common import *
from f4pga.module import Module, ModuleContext


def route_place_file(ctx: ModuleContext):
    return str(Path(ctx.takes.eblif).with_suffix('.route'))


class RouteModule(Module):
    def map_io(self, ctx: ModuleContext):
        return {
            'route': route_place_file(ctx)
        }

    def execute(self, ctx: ModuleContext):
        build_dir = str(Path(ctx.takes.eblif).parent)

        vpr_options = []
        if ctx.values.vpr_options:
            vpr_options = options_dict_to_list(ctx.values.vpr_options)

        yield 'Routing with VPR...'
        vpr(
            'route',
            VprArgs(
                ctx.share,
                ctx.takes.eblif,
                ctx.values,
                sdc_file=ctx.takes.sdc
            ),
            cwd=build_dir
        )

        if ctx.is_output_explicit('route'):
            sh_mv(route_place_file(ctx), ctx.outputs.route)

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
