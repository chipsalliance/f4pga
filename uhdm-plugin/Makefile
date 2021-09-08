# Copyright (C) 2020-2021  The SymbiFlow Authors.
#
# Use of this source code is governed by a ISC-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/ISC
#
# SPDX-License-Identifier:ISC

NAME = uhdm
SOURCES = UhdmAst.cc \
	  uhdmastfrontend.cc \
	  uhdmsurelogastfrontend.cc \
	  uhdmastreport.cc

include ../Makefile_plugin.common

CPPFLAGS += -std=c++17 -I${UHDM_INSTALL_DIR}/include/uhdm \
			-I${UHDM_INSTALL_DIR}/include/uhdm/include \
			-I${UHDM_INSTALL_DIR}/include/uhdm/headers \
			-I${UHDM_INSTALL_DIR}/include/surelog

CXXFLAGS += -Wno-inconsistent-missing-override -Wno-unused-parameter
LDFLAGS += -L${UHDM_INSTALL_DIR}/lib/uhdm -L${UHDM_INSTALL_DIR}/lib/surelog -L${UHDM_INSTALL_DIR}/lib
LDLIBS += -Wl,--whole-archive -luhdm -Wl,--no-whole-archive -lsurelog -lantlr4-runtime -lflatbuffers -lcapnp -lkj -ldl -lutil -lm -lrt -lpthread
