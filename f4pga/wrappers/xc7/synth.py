from pathlib import Path
from sys import argv as sys_argv
from os import environ
from argparse import ArgumentParser
from f4pga.wrappers import run


def arg_parser():
    parser = ArgumentParser(description="Parse flags")

    parser.add_argument(
        '-t',
        '--top',
        nargs=1,
        metavar='<top module name>',
        type=str,
        help='Top module name'
    )

    parser.add_argument(
        '-v',
        '--verilog',
        nargs='+',
        metavar='<verilog files>',
        type=str,
        help='Verilog file list'
    )

    parser.add_argument(
        '-x',
        '--xdc',
        nargs='+',
        metavar='<xdc files>',
        type=str,
        help='XDC file list'
    )

    parser.add_argument(
        '-d',
        '--device',
        nargs=1,
        metavar='<device>',
        type=str,
        help='Device type (e.g. artix7)'
    )

    parser.add_argument(
        '-p',
        '--part',
        nargs=1,
        metavar='<name>',
        type=str,
        help='Part name'
    )

    return parser.parse_args()


def main():
    share_dir_path = (Path(sys_argv[0]).resolve().parent / '../share/symbiflow').resolve()
    utils_path = share_dir_path / 'scripts'

    environ['SHARE_DIR_PATH'] = str(share_dir_path)
    environ['TECHMAP_PATH'] = str(share_dir_path / 'techmaps/xc7_vpr/techmap')
    environ['UTILS_PATH'] = str(utils_path)

    args = arg_parser()

    database_dir = environ.get('DATABASE_DIR', str(run('prjxray-config')))
    environ['DATABASE_DIR'] = database_dir

    # TODO: is this crossplatform???
    if 'PYTHON3' not in environ:
        environ['PYTHON3'] = run(['which', 'python3'])

    if not args.verilog:
        raise(Exception('Please provide at least one Verilog file\n'))

    if not args.top:
        raise(Exception('Top module must be specified\n'))

    if not args.device:
        raise(Exception('Device parameter required\n'))

    if not args.part:
        raise(Exception('Part parameter required\n'))

    out_json = f"{args.top}.json"
    synth_json = f"{args.top}_io.json"
    log = f"{args.top}_synth.log"

    environ['TOP'] = args.top
    environ['OUT_JSON'] = out_json
    environ['OUT_SDC'] = f"{args.top}.sdc"
    environ['SYNTH_JSON'] = synth_json
    environ['OUT_SYNTH_V'] = f"{args.top}_synth.v"
    environ['OUT_EBLIF'] = f"{args.top}.eblif"
    environ['PART_JSON'] = str(Path(database_dir) / f"{args.device}/{args.part}/part.json")
    environ['OUT_FASM_EXTRA'] = args.top + '_fasm_extra.fasm'

    if args.xdc:
        environ['INPUT_XDC_FILES'] = ' '.join(args.xdc)

    run(
        'yosys',
        '-p',
        f'\"tcl {(utils_path / "xc7/synth.tcl")!s}\"',
        '-l',
        'log',
        ' '.join(args.verilog)
    )

    run(
        'python3',
        str(utils_path / 'split_inouts.py'),
        '-i',
        out_json,
        '-o',
        synth_json
    )

    run(
        'yosys',
        '-p',
        f'\"read_json {synth_json}; tcl {(utils_path / "xc7/conv.tcl")!s}\"'
    )
