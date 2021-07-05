#!/usr/bin/python3

# Symbiflow Stage Module

# ----------------------------------------------------------------------------- #

import os
from sf_common import *
from sf_module import *

# ----------------------------------------------------------------------------- #

def concat_fasm(fasm: str, fasm_extra: str, output: str):
    fasm_data = None
    fasm_extra_data = None
    with open(fasm, 'r') as fasm_file, open(fasm_extra, 'r') as fasm_extra_file:
        fasm_data = fasm_file.read()
        fasm_extra_data = fasm_extra_file.read()
    data = fasm_data + '\n' + fasm_extra_data

    with open(output, 'w') as output_file:
        output_file.write(data)

def fasm_output_path(build_dir: str, top: str):
    return f'{build_dir}/{top}.fasm'

class FasmModule(Module):

    def map_io(self, ctx: ModuleContext):
        build_dir = os.path.dirname(ctx.takes.eblif)
        return {
            'fasm': fasm_output_path(build_dir, ctx.values.top)
        }
    
    def execute(self, ctx: ModuleContext):        
        build_dir = os.path.dirname(ctx.takes.eblif)
        
        vprargs = VprArgs(ctx.share, ctx.takes.eblif, ctx.values)

        optional = []
        if ctx.values.pnr_corner is not None:
            optional += ['--pnr_corner', ctx.values.pnr_corner]
        if ctx.takes.sdc:
            optional += ['--sdc', ctx.takes.sdc]

        s = ['genfasm', vprargs.arch_def,
               os.path.realpath(ctx.takes.eblif),
               '--device', vprargs.device_name,
               '--read_rr_graph', vprargs.rr_graph
        ] + vprargs.optional
        
        if get_verbosity_level() >= 2:
            yield 'Generating FASM...\n           ' + ' '.join(s)
        else:
            yield 'Generating FASM...'
        
        sub(*s, cwd=build_dir)

        default_fasm_output_name = fasm_output_path(build_dir, ctx.values.top)
        if default_fasm_output_name != ctx.outputs.fasm:
            shutil.move(default_fasm_output_name, ctx.outputs.fasm)

        if ctx.takes.fasm_extra:
            yield 'Appending extra FASM...'
            concat_fasm(ctx.outputs.fasm, ctx.takes.fasm_extra, ctx.outputs.fasm)
        else:
            yield 'No extra FASM to append'
    
    def __init__(self, _):
        self.name = 'fasm'
        self.no_of_phases = 2
        self.takes = [
            'eblif',
            'net',
            'place',
            'route',
            'fasm_extra?',
            'sdc?'
        ]
        self.produces = [ 'fasm' ]
        self.values = [
            'device',
            'top',
            'pnr_corner?'
        ] + vpr_specific_values()
        self.prod_meta = {
            'fasm': 'FPGA assembly file'
        }

ModuleClass = FasmModule
