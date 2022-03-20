#!/usr/bin/env python3

from pathlib import Path

from setuptools import setup as setuptools_setup


packagePath = Path(__file__).resolve().parent

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
)
