from pathlib import Path
from re import search as re_search

from f4pga.wrappers import (
    my_path,
    noisy_warnings,
    run
)

from f4pga.wrappers.xc7.vpr import (
    save_vpr_log,
    setup_vpr_arg_parser,
    VprArgs,
    vpr
)


def place():
    parser = setup_vpr_arg_parser()
    parser.add_argument(
        '-n',
        '--net',
        nargs='+',
        metavar='<net file>',
        type=str,
        help='NET filename'
    )
    args = parser.parse_args()

    vprargs = VprArgs(my_path(), args) + [
        '--fix_clusters',
        'constraints.place',
        '--place'
    ]
    vprargs.export()

    if not args.net:
        print('Please provide NET filename')
        exit(1)

    noisy_warnings()

    print('Generating constraints...\n')

    run(
        'symbiflow_generate_constraints',
        args.eblif,
        args.net,
        args.part,
        vprargs.arch_def,
        args.pcf
    )

    vpr(vprargs)

    save_vpr_log('place.log')


def route():
    args = setup_vpr_arg_parser().parse_args()

    vprargs = VprArgs(my_path(), args)
    vprargs.export()

    noisy_warnings(args.device)

    vprargs.optional += '--route'

    print('Routing...')
    vpr(vprargs)

    save_vpr_log('route.log')


def write_fasm():
    vprargs = VprArgs(
        my_path(),
        setup_vpr_arg_parser().parse_args()
    )

    if vprargs.eblif is None:
        raise(Exception("Argument EBLIF is required!"))

    top_ext_match = re_search('.*\\.[^.]*', vprargs.eblif)
    top = top[:top_ext_match.pos] if top_ext_match else vprargs.eblif

    fasm_extra = top + '_fasm_extra.fasm'

    noisy_warnings()

    run(
        'genfasm',
        vprargs.arch_def,
        vprargs.eblif,
        '--device', vprargs.device_name,
        vprargs.vpr_options,
        '--read_rr_graph', vprargs.rr_graph
    )

    print(f'FASM extra: {fasm_extra}\n')

    # Concatenate top.fasm with extra.fasm if necessary
    if Path(fasm_extra).is_file():
        print('writing final fasm')
        with open(top + '.fasm', 'r+<') as top_file, open(fasm_extra) as extra_file:
            cat = top_file.read()
            cat += '\n'
            cat += extra_file.read()
            top_file.seek(0)
            top_file.write(cat)
            top_file.truncate()

    save_vpr_log('fasm.log')
