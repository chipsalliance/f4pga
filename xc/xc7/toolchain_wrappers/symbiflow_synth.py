#!/usr/bin/python3

import sys
import os
import argparse
from symbiflow_common import *

def setup_arg_parser():
    parser = argparse.ArgumentParser(description="Parse flags")
    parser.add_argument('-t', '--top', nargs=1, metavar='<top module name>',
                        type=str, help='Top module name')
    parser.add_argument('-v', '--verilog', nargs='+', metavar='<verilog files>',
                        type=str, help='Verilog file list')
    parser.add_argument('-x', '--xdc', nargs='+', metavar='<xdc files>',
                        type=str, help='XDC file list')
    parser.add_argument('-d', '--device', nargs=1, metavar='<device>',
                        type=str, help='Device type (e.g. artix7)')
    parser.add_argument('-p', '--part', nargs=1, metavar='<name>',
                        type=str, help='Part name')
    return parser

mypath = os.path.realpath(sys.argv[0])
mypath = os.path.dirname(mypath)

share_dir_path = os.path.realpath(os.path.join(mypath, '../share/symbiflow'))
techmap_path = os.path.join(share_dir_path, 'techmaps/xc7_vpr/techmap')
utils_path = os.path.join(share_dir_path, 'scripts')
synth_tcl_path = os.path.join(utils_path, 'xc7/synth.tcl')
conv_tcl_path = os.path.join(utils_path, 'xc7/conv.tcl')
split_inouts = os.path.join(utils_path, 'split_inouts.py')

os.environ['SHARE_DIR_PATH'] = share_dir_path
os.environ['TECHMAP_PATH'] = techmap_path
os.environ['UTILS_PATH'] = utils_path

parser = setup_arg_parser()

args = parser.parse_args()

if not os.environ['DATABASE_DIR']:
    os.environ['DATABASE_DIR'] = sub(['prjxray-config'])
database_dir = os.environ['DATABASE_DIR']

# TODO: is this crossplatform???
if not os.environ['PYTHON3']:
    os.environ['PYTHON3'] = sub(['which', 'python3'])

if not args.verilog:
    print('Please provide at least one Verilog file\n')
    exit(0)
if not args.top:
    print('Top module must be specified\n')
    exit(0)
if not args.device:
    print('Device parameter required\n')
    exit(0)
if not args.part:
    print('Part parameter required\n')
    exit(0)

out_json = args.top + '.json'
synth_json = args.top + '_io.json'
log = args.top + '_synth.log'

os.environ['TOP'] = args.top
os.environ['OUT_JSON'] = out_json
os.environ['OUT_SDC'] = args.top + '.sdc'
os.environ['SYNTH_JSON'] = synth_json
os.environ['OUT_SYNTH_V'] = args.top + '_synth.v'
os.environ['OUT_EBLIF'] = args.top + '.eblif'
os.environ['PART_JSON'] = \
    os.path.join(database_dir, args.device, args.part, 'part.json')
os.environ['OUT_FASM_EXTRA'] = args.top + '_fasm_extra.fasm'

if args.xdc:
    os.environ['INPUT_XDC_FILES'] = ' '.join(args.xdc)

verilog_paths_str = ' '.join(args.verilog)

print('------------------------------------> In symbiflow_synth!!!\n')

sub('yosys', '-p', f'\"tcl {synth_tcl_path}\"', '-l', 'log', verilog_paths_str)
sub('python3', split_inouts, '-i', out_json, '-o', synth_json)
sub('yosys', '-p', f'\"read_json {synth_json}; tcl {conv_tcl_path}\"')
