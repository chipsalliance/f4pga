# Copyright 2020-2022 F4PGA Authors
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

NAME = systemverilog
SOURCES = UhdmAst.cc \
	  uhdmastfrontend.cc \
	  uhdmcommonfrontend.cc \
	  uhdmsurelogastfrontend.cc \
	  uhdmastreport.cc

# Directory to search for Surelog and UHDM libraries
UHDM_INSTALL_DIR ?= /usr/local

include ../Makefile_plugin.common

CPPFLAGS += -std=c++17 -Wall -W -Wextra -Werror \
              -I${UHDM_INSTALL_DIR}/include \
	      -I${UHDM_INSTALL_DIR}/include/Surelog

CXXFLAGS += -Wno-unused-parameter
LDFLAGS += -L${UHDM_INSTALL_DIR}/lib/uhdm -L${UHDM_INSTALL_DIR}/lib/surelog -L${UHDM_INSTALL_DIR}/lib -L${UHDM_INSTALL_DIR}/lib64/uhdm -L${UHDM_INSTALL_DIR}/lib64/surelog -L${UHDM_INSTALL_DIR}/lib64
LDLIBS += -Wl,--whole-archive -luhdm -Wl,--no-whole-archive -lsurelog -lantlr4-runtime -lflatbuffers -lcapnp -lkj -ldl -lutil -lm -lrt -lpthread
