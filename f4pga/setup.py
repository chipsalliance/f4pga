#!/usr/bin/env python3

from pathlib import Path

from setuptools import setup as setuptools_setup

from os import environ
F4PGA_FAM = environ.get('F4PGA_FAM', 'xc7')


packagePath = Path(__file__).resolve().parent

sf = "symbiflow"
shwrappers = "f4pga.wrappers.sh.__init__"

wrapper_entrypoints = [
    f"{sf}_generate_constraints = {shwrappers}:generate_constraints",
    f"{sf}_pack = {shwrappers}:pack",
    f"{sf}_place = {shwrappers}:place",
    f"{sf}_route = {shwrappers}:route",
    f"{sf}_synth = {shwrappers}:synth",
    f"{sf}_write_bitstream = {shwrappers}:write_bitstream",
    f"{sf}_write_fasm = {shwrappers}:write_fasm",
] if F4PGA_FAM == 'xc7' else [
#    f"{sf}_generate_constraints = {shwrappers}:generate_constraints",
    f"{sf}_pack = {shwrappers}:pack",
    f"{sf}_place = {shwrappers}:place",
    f"{sf}_route = {shwrappers}:route",
#    f"{sf}_synth = {shwrappers}:synth",
    f"{sf}_write_fasm = {shwrappers}:write_fasm",
#      f"{sf}_write_xml_rr_graph = {shwrappers}:write_xml_rr_graph",  # Is this unused ???
#      f"vpr_common = {shwrappers}:vpr_common",
#      f"{sf}_analysis = {shwrappers}:analysis",  # Is this unused ???
#      f"{sf}_repack = {shwrappers}:repack",  # Is this unused ???
#      f"{sf}_generate_bitstream = {shwrappers}:generate_bitstream",  # Is this unused ???
#      f"{sf}_generate_libfile = {shwrappers}:generate_libfile",  # Is this unused ???
#      f"ql_{sf} = {shwrappers}:ql",
]

setuptools_setup(
    name=packagePath.name,
    version="0.0.0",
    license="Apache-2.0",
    author="F4PGA Authors",
    description="F4PGA.",
    url="https://github.com/chipsalliance/f4pga",
    packages=[
        "f4pga.wrappers.sh",
    ],
    package_dir={"f4pga": "."},
    package_data={
        'f4pga.wrappers.sh': ['xc7/*.f4pga.sh', 'quicklogic/*.f4pga.sh']
    },
    classifiers=[],
    python_requires='>=3.6',
    entry_points={
        "console_scripts": wrapper_entrypoints
    },
)
