from pathlib import Path
from os import environ
from sys import argv as sys_argv
from subprocess import run as subprocess_run


def run(*args):
    """
    Execute subroutine
    """
    out = subprocess_run(args, capture_output=True)
    if out.returncode != 0:
        raise(Exception(out.returncode))
    return out.stdout


def noisy_warnings(device):
    """
    Emit some noisy warnings
    """
    environ['OUR_NOISY_WARNINGS'] = f'noisy_warnings-{device}_pack.log'


def my_path():
    """
    Get current PWD
    """
    return str(Path(sys_argv[0]).resolve().parent)
