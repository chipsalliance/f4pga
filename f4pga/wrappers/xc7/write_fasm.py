#!/usr/bin/python3

import shutil
import re
from f4pga.wrappers.xc7.common import (
    my_path,
    setup_vpr_arg_parser,
    VprArgs,
    sub
)

def main():
    mypath = my_path()
    parser = setup_vpr_arg_parser()
    args = parser.parse_args()
    vprargs = VprArgs(mypath, args)


    top = vprargs.eblif
    top_ext_match = re.search('.*\\.[^.]*', vprargs.eblif)
    if top_ext_match:
        top = top[:top_ext_match.pos]

    fasm_extra = top + '_fasm_extra.fasm'

    noisy_warnings()

    sub('genfasm',
        vprargs.arch_def,
        vprargs.eblif,
        '--device', vprargs.device_name,
        vprargs.vpr_options,
        '--read_rr_graph', vprargs.rr_graph)

    print(f'FASM extra: {fasm_extra}\n')

    # Concatenate top.fasm with extra.fasm if necessary
    if os.path.isfile(fasm_extra):
        print('writing final fasm')
        with open(top + '.fasm', 'r+<') as top_file, open(fasm_extra) as extra_file:
            cat = top_file.read()
            cat += '\n'
            cat += extra_file.read()
            top_file.seek(0)
            top_file.write(cat)
            top_file.truncate()

    save_vpr_log('fasm.log')
