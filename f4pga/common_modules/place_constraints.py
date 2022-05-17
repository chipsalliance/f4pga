from pathlib import Path
from f4pga.common import *
from f4pga.module import Module, ModuleContext


class PlaceConstraintsModule(Module):
    def map_io(self, ctx: ModuleContext):
        return {
            'place_constraints': f'{Path(ctx.takes.net).stem!s}.preplace'
        }

    def execute(self, ctx: ModuleContext):
        arch_dir = str(Path(ctx.share) / 'arch')
        arch_def = str(Path(arch_dir) / ctx.values.device / 'arch.timing.xml')

        database = sub('prjxray-config').decode().replace('\n', '')

        yield 'Generating .place...'

        extra_opts: 'list[str]'
        if ctx.values.extra_opts:
            extra_opts = options_dict_to_list(ctx.values.extra_opts)
        else:
            extra_opts = []

        data = sub(*(['python3', ctx.values.script,
                      '--net', ctx.takes.net,
                      '--arch', arch_def,
                      '--blif', ctx.takes.eblif,
                      '--input', ctx.takes.io_place,
                      '--db_root', database,
                      '--part', ctx.values.part_name]
                      + extra_opts))

        yield 'Saving place constraint data...'
        with open(ctx.outputs.place_constraints, 'wb') as f:
            f.write(data)

    def __init__(self, _):
        self.name = 'place_constraints'
        self.no_of_phases = 2
        self.takes = [
            'eblif',
            'net',
            'io_place'
        ]
        self.produces = [ 'place_constraints' ]
        self.values = [
            'device',
            'part_name',
            'script',
            'extra_opts?'
        ]

ModuleClass = PlaceConstraintsModule
