# Copyright (C) 2022  The SymbiFlow Authors.
#
# Use of this source code is governed by a ISC-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/ISC
#
# SPDX-License-Identifier:ISC

TESTBENCH = bram_sdp_tb.v
POST_SYNTH = bram_sdp_32x512_post_synth bram_sdp_16x1024_post_synth bram_sdp_8x2048_post_synth bram_sdp_4x4096_post_synth
ADDR_WIDTH = 9 10 11 12
DATA_WIDTH = 32 16 8 4
TOP = BRAM_SDP_32x512 BRAM_SDP_16x1024 BRAM_SDP_8x2048 BRAM_SDP_4x4096
TEST_CASES = $(seq 0 3)
ADDR_DEFINES = $(foreach awidth, $(ADDR_WIDTH),-DADDR_WIDTH="$(awidth)")
DATA_DEFINES = $(foreach dwidth, $(DATA_WIDTH),-DDATA_WIDTH="$(dwidth)")
TOP_DEFINES = $(foreach top, $(TOP),-DTOP="$(top)")
VCD_DEFINES = $(foreach vcd, $(POST_SYNTH),-DVCD="$(vcd).vcd")

SIM_LIBS = $(shell find ../../../../qlf_k6n10f -name "*.v" -not -name "*_map.v")

define simulate_post_synth
	@iverilog  -vvvv -g2005 $(word $(1),$(ADDR_DEFINES)) $(word $(1),$(DATA_DEFINES)) $(word $(1),$(TOP_DEFINES)) $(word $(1),$(VCD_DEFINES)) -o $(word $(1),$(POST_SYNTH)).vvp $(word $(1),$(POST_SYNTH)).v $(SIM_LIBS) $(TESTBENCH) > $(word $(1),$(POST_SYNTH)).vvp.log 2>&1
	@vvp -vvvv $(word $(1),$(POST_SYNTH)).vvp > $(word $(1),$(POST_SYNTH)).vcd.log 2>&1
endef

define clean_post_synth_sim
	@rm -rf  $(word $(1),$(POST_SYNTH)).vcd $(word $(1),$(POST_SYNTH)).vvp $(word $(1),$(POST_SYNTH)).vvp.log $(word $(1),$(POST_SYNTH)).vcd.log
endef

sim:
	$(call simulate_post_synth,1)
	$(call simulate_post_synth,2)
	$(call simulate_post_synth,3)
	$(call simulate_post_synth,4)
