#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright (C) 2022 F4PGA Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

from pathlib import Path
from os import environ


FPGA_FAM = environ.get("FPGA_FAM", "xc7")
if FPGA_FAM not in ["xc7", "eos-s3", "qlf_k4n8", "ice40"]:
    raise (Exception(f"Unsupported FPGA_FAM <{FPGA_FAM}>!"))

F4PGA_DEBUG = environ.get("F4PGA_DEBUG")

install_dir = environ.get("F4PGA_INSTALL_DIR")
if install_dir is None:
    default_install_dir = Path("/usr/local")
    if F4PGA_DEBUG is not None:
        print("Environment variable F4PGA_INSTALL_DIR is undefined!")
        print(f"Using default {default_install_dir}")
    F4PGA_INSTALL_DIR = default_install_dir
else:
    F4PGA_INSTALL_DIR = Path(install_dir)

F4PGA_SHARE_DIR = Path(environ.get("F4PGA_SHARE_DIR", F4PGA_INSTALL_DIR / FPGA_FAM / "share/f4pga"))
