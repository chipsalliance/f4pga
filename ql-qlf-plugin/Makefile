# Copyright (C) 2020-2021  The SymbiFlow Authors.
#
# Use of this source code is governed by a ISC-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/ISC
#
# SPDX-License-Identifier:ISC

NAME = ql-qlf
SOURCES = synth_quicklogic.cc \
   	      ql-dsp.cc \
		  pp3_braminit.cc
include ../Makefile_plugin.common

COMMON		= common
QLF_K4N8_DIR 	= ql-qlf-k4n8
QLF_K6N10_DIR 	= ql-qlf-k6n10
PP3_DIR			= pp3
VERILOG_MODULES = $(COMMON)/cells_sim.v 			\
		  $(QLF_K4N8_DIR)/qlf_k4n8_arith_map.v 		\
		  $(QLF_K4N8_DIR)/qlf_k4n8_cells_sim.v 		\
		  $(QLF_K4N8_DIR)/qlf_k4n8_ffs_map.v 		\
		  $(QLF_K6N10_DIR)/qlf_k6n10_arith_map.v 	\
		  $(QLF_K6N10_DIR)/qlf_k6n10_brams_map.v 	\
		  $(QLF_K6N10_DIR)/qlf_k6n10_brams.txt 		\
		  $(QLF_K6N10_DIR)/qlf_k6n10_cells_sim.v 	\
		  $(QLF_K6N10_DIR)/qlf_k6n10_ffs_map.v 		\
		  $(QLF_K6N10_DIR)/qlf_k6n10_dsp_map.v 		\
		  $(QLF_K6N10_DIR)/qlf_k6n10_lut_map.v		\
		  $(PP3_DIR)/pp3_abc9_map.v    \
		  $(PP3_DIR)/pp3_abc9_model.v  \
		  $(PP3_DIR)/pp3_abc9_unmap.v  \
		  $(PP3_DIR)/pp3_cells_map.v   \
		  $(PP3_DIR)/pp3_cells_sim.v   \
		  $(PP3_DIR)/pp3_ffs_map.v     \
		  $(PP3_DIR)/pp3_latches_map.v \
		  $(PP3_DIR)/pp3_lut_map.v     \
		  $(PP3_DIR)/pp3_lutdefs.txt   \
		  $(PP3_DIR)/pp3_brams_map.v   \
		  $(PP3_DIR)/pp3_brams.txt     \
		  $(PP3_DIR)/pp3_bram_init_8_16.vh  \
		  $(PP3_DIR)/pp3_bram_init_32.vh

retrieve-pmgen:=$(shell mkdir -p pmgen && wget -nc -O pmgen/pmgen.py https://raw.githubusercontent.com/SymbiFlow/yosys/master%2Bwip/passes/pmgen/pmgen.py)

pre-build:=$(shell python3 pmgen/pmgen.py -o pmgen/ql-dsp-pm.h -p ql_dsp ql_dsp.pmg)

install_modules: $(VERILOG_MODULES)
	$(foreach f,$^,install -D $(f) $(DATA_DIR)/quicklogic/$(notdir $(f));)

install: install_modules

clean:
	$(MAKE) -f ../Makefile_plugin.common $@
	rm -f *pm.h
