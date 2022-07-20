from f4pga.flows.module import *
from f4pga.flows.common import *

class NextPnrBaseModule(Module):
    nextpnr_variant: str
    extra_nextpnr_opts: 'list[str]'
    nextpnr_log_name: 'str | None'
    use_interchange: bool

    def map_io(self, ctx: ModuleContext) -> 'dict[str, ]':
        return {}

    def execute(self, ctx: ModuleContext):
        nextpnr_cmd = f'nextpnr-{self.nextpnr_variant}'

        nextpnr_opts = [
            '--top', ctx.values.top,
            '--placer', ctx.values.placer,
            '--router', ctx.values.router,
        ]

        if self.use_interchange:
            nextpnr_opts += ['--netlist', ctx.takes.ic_logical_netlist]
        else:
            nextpnr_opts += ['--json', ctx.takes.json]

        if ctx.values.prepack_script is not None:
            nextpnr_opts += ['--pre-pack', ctx.values.prepack_script]
        if ctx.values.preplace_script is not None:
            nextpnr_opts += ['--pre-place', ctx.values.preplace_script]
        if ctx.values.preroute_script is not None:
            nextpnr_opts += ['--pre-route', ctx.values.preroute_script]
        if ctx.values.postroute_script is not None:
            nextpnr_opts += ['--post-poute', ctx.values.postroute_script]
        if ctx.values.fail_script is not None:
            nextpnr_opts += ['--on-fail', ctx.values.fail_script]

        if ctx.values.thread_count:
            nextpnr_opts += ['--threads', ctx.values.thread_count]
        if ctx.values.parallel:
            nextpnr_opts += ['--parallel-refine']

        nextpnr_opts += self.extra_nextpnr_opts


        if get_verbosity_level() >= 2:
            yield  'Place-and-routing with nextpnr...\n ' \
                  f'{nextpnr_cmd} {" ".join(nextpnr_opts)}'
        else:
            yield 'Place-and-routing with nextpnr...'


        res = sub(nextpnr_cmd, *nextpnr_opts)

        yield 'Saving log...'
        log_path = getattr(ctx.outputs, self.nextpnr_log_name)
        if log_path is not None:
            with open(log_path, 'w') as f:
                f.write(res.decode())


    def __init__(self, params: 'dict[str, ]', r_env: ResolutionEnv,
                 instance_name: str = '<anonymous>', interchange=False):
        super().__init__(params, r_env, instance_name)
        self.nextpnr_variant = 'unknown'
        self.extra_nextpnr_opts = []

        self.no_of_phases = 2
        self.use_interchange = interchange

        if self.use_interchange:
            self.takes = [
                'ic_logical_netlist',
            ]
        else:
            self.takes = [
                'json',
            ]

        self.values = [
            'top',
            'placer',
            'router',
            'prepack_script?',
            'preplace_script?',
            'preroute_script?',
            'postroute_script?',
            'fail_script?',
            'thread_count?',
            'parallel?'
        ]

        self.nextpnr_log_name = f'nextpnr_{instance_name}_log'

        self.produces = [
            f'{self.nextpnr_log_name}!'
        ]