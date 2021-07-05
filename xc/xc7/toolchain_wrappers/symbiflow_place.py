#!/usr/bin/python3

import shutil
from symbiflow_common import *

mypath = my_path()
parser = setup_vpr_arg_parser()
parser.add_argument('-n', '--net', nargs='+', metavar='<net file>',
                    type=str, help='NET filename')
args = parser.parse_args()
vprargs = VprArgs(mypath, args)
vprargs += ['--fix_clusters', 'constraints.place', '--place']
vprargs.export()

if not args.net:
    print('Please provide NET filename')
    exit(1)

noisy_warnings()

print('Generating constraints...\n')

sub('symbiflow_generate_constraints',
    args.eblif, args.net, args.part, vprargs.arch_def, args.pcf)

vpr(vprargs)

save_vpr_log('place.log')