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
          pp3_braminit.cc \
          quicklogic_eqn.cc \
          ql-edif.cc

include ../Makefile_plugin.common

COMMON          = common
QLF_K4N8_DIR    = qlf_k4n8
QLF_K6N10_DIR   = qlf_k6n10
QLF_K6N10F_DIR   = qlf_k6n10f
PP3_DIR         = pp3
VERILOG_MODULES = $(COMMON)/cells_sim.v         \
                  $(QLF_K4N8_DIR)/arith_map.v   \
                  $(QLF_K4N8_DIR)/cells_sim.v   \
                  $(QLF_K4N8_DIR)/ffs_map.v     \
                  $(QLF_K6N10_DIR)/arith_map.v \
                  $(QLF_K6N10_DIR)/brams_map.v \
                  $(QLF_K6N10_DIR)/brams.txt   \
                  $(QLF_K6N10_DIR)/cells_sim.v \
                  $(QLF_K6N10_DIR)/ffs_map.v   \
                  $(QLF_K6N10_DIR)/dsp_map.v   \
                  $(QLF_K6N10_DIR)/lut_map.v   \
                  $(QLF_K6N10F_DIR)/arith_map.v \
                  $(QLF_K6N10F_DIR)/brams_map.v \
                  $(QLF_K6N10F_DIR)/brams.txt   \
                  $(QLF_K6N10F_DIR)/cells_sim.v \
                  $(QLF_K6N10F_DIR)/ffs_map.v   \
                  $(QLF_K6N10F_DIR)/dsp_map.v   \
                  $(PP3_DIR)/abc9_map.v    \
                  $(PP3_DIR)/abc9_model.v  \
                  $(PP3_DIR)/abc9_unmap.v  \
                  $(PP3_DIR)/cells_map.v   \
                  $(PP3_DIR)/cells_sim.v   \
                  $(PP3_DIR)/ffs_map.v     \
                  $(PP3_DIR)/latches_map.v \
                  $(PP3_DIR)/lut_map.v     \
                  $(PP3_DIR)/lutdefs.txt   \
                  $(PP3_DIR)/brams_sim.v   \
                  $(PP3_DIR)/brams_map.v   \
                  $(PP3_DIR)/brams.txt     \
                  $(PP3_DIR)/bram_init_8_16.vh \
                  $(PP3_DIR)/bram_init_32.vh   \
                  $(PP3_DIR)/qlal4s3b_sim.v    \
                  $(PP3_DIR)/mult_sim.v        \
                  $(PP3_DIR)/qlal3_sim.v       \

retrieve-pmgen:=$(shell mkdir -p pmgen && wget -nc -O pmgen/pmgen.py https://raw.githubusercontent.com/SymbiFlow/yosys/master%2Bwip/passes/pmgen/pmgen.py)

pre-build:=$(shell python3 pmgen/pmgen.py -o pmgen/ql-dsp-pm.h -p ql_dsp ql_dsp.pmg)

install_modules: $(VERILOG_MODULES)
	$(foreach f,$^,install -D $(f) $(DATA_DIR)/quicklogic/$(f);)

install: install_modules

clean:
	$(MAKE) -f ../Makefile_plugin.common $@
	rm -f *pm.h
