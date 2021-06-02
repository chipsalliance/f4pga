# Copyright (C) 2020-2021  The SymbiFlow Authors.
#
# Use of this source code is governed by a ISC-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/ISC
#
# SPDX-License-Identifier:ISC

NAME = xdc
SOURCES = xdc.cc
include ../Makefile_plugin.common
VERILOG_MODULES = BANK.v

install_modules: $(VERILOG_MODULES)
	install -D $< $(PLUGINS_DIR)/fasm_extra_modules/$<

install: install_modules
