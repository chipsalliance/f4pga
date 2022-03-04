from typing import List
from pathlib import Path
from argparse import ArgumentParser
from os import environ
from shutil import move as sh_mv

from f4pga.wrappers import run

class VprArgs:
    arch_dir: Path
    arch_def: Path
    lookahead: Path
    rr_graph: Path
    rr_graph_xml: Path
    place_delay: Path
    device_name: Path
    eblif: str
    vpr_options: str
    optional: List[str]

    def __init__(self, mypath, args):
        self.arch_dir = (Path(mypath) / '../share/symbiflow/arch' / args.device).resolve()
        self.arch_def = self.arch_dir / 'arch.timing.xml'
        filename = f'rr_graph_{args.device}'
        self.lookahead = self.arch_dir / f'{filename}.lookahead.bin'
        self.rr_graph = self.arch_dir / f'{filename}.rr_graph.real.bin'
        self.rr_graph_xml = self.arch_dir / f'{filename}.rr_graph.real.xml'
        self.place_delay = self.arch_dir / f'{filename}.place_delay.bin'
        self.device_name = args.device.replace('_', '-')
        self.eblif = args.eblif
        self.vpr_options = args.vpr_options
        self.optional = ['--sdc_file', args.sdc] if args.sdc else []

    def export(self):
        environ['ARCH_DIR'] = str(self.arch_dir)
        environ['ARCH_DEF'] = str(self.arch_def)
        environ['LOOKAHEAD'] = str(self.lookahead)
        environ['RR_GRAPH'] = str(self.rr_graph)
        environ['RR_GRAPH_XML'] = str(self.rr_graph_xml)
        environ['PLACE_DELAY'] = str(self.place_delay)
        environ['DEVICE_NAME'] = str(self.device_name)


def setup_vpr_arg_parser():
    parser = ArgumentParser(description="Parse flags")

    parser.add_argument(
        '-d',
        '--device',
        nargs=1,
        metavar='<device>',
        type=str,
        help='Device type (e.g. artix7)',
        default='artix7'
    )

    parser.add_argument(
        '-e',
        '--eblif',
        nargs=1,
        metavar='<eblif file>',
        type=str,
        help='EBLIF filename'
    )

    parser.add_argument(
        '-p',
        '--pcf',
        nargs=1,
        metavar='<pcf file>',
        type=str,
        help='PCF filename'
    )

    parser.add_argument(
        '-P',
        '--part',
        nargs=1,
        metavar='<name>',
        type=str,
        help='Part name'
    )

    parser.add_argument(
        '-s',
        '--sdc',
        nargs=1,
        metavar='<sdc file>',
        type=str,
        help='SDC file'
    )

    parser.add_argument(
        '-a',
        '--vpr_options',
        metavar='<opts>',
        type=str,
        help='Additional VPR options'
    )

    parser.add_argument(
        'additional_vpr_args',
        nargs='*',
        metavar='<args>',
        type=str,
        help='Additional arguments for vpr command'
    )

    return parser


def vpr(vprargs: VprArgs):
    """
    Execute `vpr`
    """
    return run(
        'vpr',
        vprargs.arch_def,
        vprargs.eblif,
        '--device', vprargs.device_name,
        vprargs.vpr_options,
        '--read_rr_graph', vprargs.rr_graph,
        '--read_router_lookahead', vprargs.lookahead,
        'read_placement_delay_lookup', vprargs.place_delay,
        *vprargs.optional
    )


def save_vpr_log(filename):
    """
    Save VPR log.
    """
    sh_mv('vpr_stdout.log', filename)
