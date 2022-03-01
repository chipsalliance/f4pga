#!/usr/bin/python3

# Symbiflow Stage Module

# ----------------------------------------------------------------------------- #

import os
import re
from f4pga.sf_common import *
from f4pga.sf_module import *

# ----------------------------------------------------------------------------- #

DEFAULT_TIMING_RPT = 'pre_pack.report_timing.setup.rpt'
DEFAULT_UTIL_RPT = 'packing_pin_util.rpt'

class PackModule(Module):
    def map_io(self, ctx: ModuleContext):
        p = file_noext(ctx.takes.eblif)
        build_dir = os.path.dirname(p)

        return {
            'net': p + '.net',
            'util_rpt': os.path.join(build_dir, DEFAULT_UTIL_RPT),
            'timing_rpt': os.path.join(build_dir, DEFAULT_TIMING_RPT)
        }

    def execute(self, ctx: ModuleContext):
        vpr_args = VprArgs(ctx.share, ctx.takes.eblif, ctx.values,
                           sdc_file=ctx.takes.sdc)
        build_dir = os.path.dirname(ctx.outputs.net)

        noisy_warnings(ctx.values.device)

        yield 'Packing with VPR...'
        vpr('pack', vpr_args, cwd=build_dir)

        og_log = os.path.join(build_dir, 'vpr_stdout.log')

        yield 'Moving/deleting files...'
        if ctx.outputs.pack_log:
            shutil.move(og_log, ctx.outputs.pack_log)
        else:
            os.remove(og_log)

        if ctx.outputs.timing_rpt:
            shutil.move(os.path.join(build_dir, DEFAULT_TIMING_RPT),
                        ctx.outputs.timing_rpt)
        if ctx.outputs.util_rpt:
            shutil.move(os.path.join(build_dir, DEFAULT_UTIL_RPT),
                        ctx.outputs.util_rpt)

    def __init__(self, _):
        self.name = 'pack'
        self.no_of_phases = 2
        self.takes = [
            'eblif',
            'sdc?'
        ]
        self.produces = [
            'net',
            'util_rpt',
            'timing_rpt',
            'pack_log!'
        ]
        self.values = [
            'device',
        ] + vpr_specific_values()

ModuleClass = PackModule
