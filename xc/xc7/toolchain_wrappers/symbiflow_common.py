import subprocess
import argparse
import os
import shutil

class VprArgs:
    arch_dir: str
    arch_def: str
    lookahead: str
    rr_graph: str
    rr_graph_xml: str
    place_delay: str
    device_name: str
    eblif: str
    vpr_options: str
    optional: list[str]

    def __init__(self, mypath, args):
        self.arch_dir = \
            os.path.join(mypath, '../share/symbiflow/arch/', args.device)
        self.arch_dir = os.path.realpath(self.arch_dir)
        self.arch_def = os.path.join(self.arch_dir, 'arch.timing.xml')
        self.lookahead = \
            os.path.join(self.arch_dir,
                         'rr_graph_' + args.device + '.lookahead.bin')
        self.rr_graph = \
            os.path.join(self.arch_dir,
                         'rr_graph_' + args.device + '.rr_graph.real.bin')
        self.rr_graph_xml = \
            os.path.join(self.arch_dir,
                         'rr_graph_' + args.device + '.rr_graph.real.xml')
        self.place_delay = \
            os.path.join(self.arch_dir,
                         'rr_graph_' + args.device + '.place_delay.bin')
        self.device_name = args.device.replace('_', '-')
        self.eblif = args.eblif
        self.vpr_options = args.vpr_options
        self.optional = []
        if args.sdc:
            self.optional += ['--sdc_file', args.sdc]
    
    def export(self):
        os.environ['ARCH_DIR'] = self.arch_dir
        os.environ['ARCH_DEF'] = self.arch_def
        os.environ['LOOKAHEAD'] = self.lookahead
        os.environ['RR_GRAPH'] = self.rr_graph
        os.environ['RR_GRAPH_XML'] = self.rr_graph_xml
        os.environ['PLACE_DELAY'] = self.place_delay
        os.environ['DEVICE_NAME'] = self.device_name

def setup_vpr_arg_parser():
    parser = argparse.ArgumentParser(description="Parse flags")
    parser.add_argument('-d', '--device', nargs=1, metavar='<device>',
                        type=str, help='Device type (e.g. artix7)')
    parser.add_argument('-e', '--eblif', nargs=1, metavar='<eblif file>',
                        type=str, help='EBLIF filename')
    parser.add_argument('-p', '--pcf', nargs=1, metavar='<pcf file>',
                        type=str, help='PCF filename')
    parser.add_argument('-P', '--part', nargs=1, metavar='<name>',
                        type=str, help='Part name')
    parser.add_argument('-s', '--sdc', nargs=1, metavar='<sdc file>',
                        type=str, help='SDC file')
    parser.add_argument('-a', '--additional_vpr_options', metavar='<opts>',
                        type=str, help='Additional VPR options')
    parser.add_argument('additional_vpr_args', nargs='*', metavar='<args>',
                        type=str, help='Additional arguments for vpr command')
    return parser

# Exwecute subroutine
def sub(*args):
    out = subprocess.run(args, capture_output=True)
    if out.returncode != 0:
        exit(out.returncode)
    return out.stdout

# Execute `vpr`
def vpr(vprargs: VprArgs):
    return sub('vpr',
               vprargs.arch_def,
               vprargs.eblif,
               '--device', vprargs.device_name,
               vprargs.vpr_options,
               '--read_rr_graph', vprargs.rr_graph,
               '--read_router_lookahead', vprargs.lookahead,
               'read_placement_delay_lookup', vprargs.place_delay,
               *vprargs.optional)

# Emit some noisy warnings
def noisy_warnings(device):
    os.environ['OUR_NOISY_WARNINGS'] = 'noisy_warnings-' + device + '_pack.log'

# Get current PWD
def my_path():
    mypath = os.path.realpath(sys.argv[0])
    return os.path.dirname(mypath)

# Save VPR log
def save_vpr_log(filename):
    shutil.move('vpr_stdout.log', filename)