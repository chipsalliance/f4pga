# Python entrypoint for the shell wrappers moved from arch-defs

from sys import argv as sys_argv, stdout, stderr
from os import environ
from pathlib import Path
from subprocess import check_call


ROOT = Path(__file__).resolve().parent
F4PGA_FAM = environ.get('F4PGA_FAM', 'xc7')
SH_SUBDIR = 'quicklogic' if F4PGA_FAM == 'eos-s3' else F4PGA_FAM


def run_sh(script):
    stdout.flush()
    stderr.flush()
    check_call([str(script)]+sys_argv[1:])


def generate_constraints():
    print("F4PGA (old) generate constraints")
    run_sh(ROOT / SH_SUBDIR / "generate_constraints.f4pga.sh")


def pack():
    print("F4PGA (old) pack")
    run_sh(ROOT / SH_SUBDIR / "pack.f4pga.sh")


def place():
    print("F4PGA (old) place")
    run_sh(ROOT / SH_SUBDIR / "place.f4pga.sh")


def route():
    print("F4PGA (old) route")
    run_sh(ROOT / SH_SUBDIR / "route.f4pga.sh")


def synth():
    print("F4PGA (old) synth")
    run_sh(ROOT / SH_SUBDIR / "synth.f4pga.sh")


def write_bitstream():
    print("F4PGA (old) write bitstream")
    run_sh(ROOT / SH_SUBDIR / "write_bitstream.f4pga.sh")


def write_fasm():
    print("F4PGA (old) write fasm")
    run_sh(ROOT / SH_SUBDIR / "write_fasm.f4pga.sh")


def write_xml_rr_graph():
    print("F4PGA (old) write xlm rr graph")
    run_sh(ROOT / SH_SUBDIR / "write_xml_rr_graph.f4pga.sh")


def vpr_common():
    print("F4PGA (old) vpr common")
    run_sh(ROOT / SH_SUBDIR / "vpr_common.f4pga.sh")


def analysis():
    print("F4PGA (old) analysis")
    run_sh(ROOT / "quicklogic/analysis.f4pga.sh")


def repack():
    print("F4PGA (old) repack")
    run_sh(ROOT / "quicklogic/repack.f4pga.sh")


def generate_bitstream():
    print("F4PGA (old) generate_bitstream")
    run_sh(ROOT / "quicklogic/generate_bitstream.f4pga.sh")


def generate_libfile():
    print("F4PGA (old) generate_libfile")
    run_sh(ROOT / "quicklogic/generate_libfile.f4pga.sh")


def ql():
    print("F4PGA (old) ql")
    run_sh(ROOT / "quicklogic/ql.f4pga.sh")
