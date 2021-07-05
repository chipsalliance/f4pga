#!/usr/bin/python3

import argparse
import subprocess
import os
import shutil
from symbiflow_common import *

mypath = my_path()
parser = setup_vpr_arg_parser()
args = parser.parse_args()

vprargs = VprArgs(mypath, args)
vprargs.export()

noisy_warnings(args.device)

vprargs.optional += '--route'

print('Routing...')
vpr(vprargs)

save_vpr_log('route.log')