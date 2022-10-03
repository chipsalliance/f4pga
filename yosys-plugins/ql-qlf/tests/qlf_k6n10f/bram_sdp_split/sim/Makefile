# Copyright (C) 2019-2022 The SymbiFlow Authors
#
# Use of this source code is governed by a ISC-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/ISC
#
# SPDX-License-Identifier: ISC

TESTBENCH = bram_sdp_split_tb.v
POST_SYNTH = bram_sdp_split_2x18x1024_post_synth bram_sdp_split_2x16x1024_post_synth bram_sdp_split_2x9x2048_post_synth bram_sdp_split_2x8x2048_post_synth bram_sdp_split_2x4x4096_post_synth bram_sdp_split_2x2x8192_post_synth bram_sdp_split_2x1x16384_post_synth
ADDR_WIDTH = 10 10 11 11 12 13 14
DATA_WIDTH = 18 16 9 8 4 2 1
TOP = BRAM_SDP_SPLIT_2x18x1024 BRAM_SDP_SPLIT_2x16x1024 BRAM_SDP_SPLIT_2x9x2048 BRAM_SDP_SPLIT_2x8x2048 BRAM_SDP_SPLIT_2x4x4096 BRAM_SDP_SPLIT_2x2x8192 BRAM_SDP_SPLIT_2x1x16384
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

#FIXME: $(call simulate_post_synth,3)
sim:
	$(call simulate_post_synth,1)
	$(call simulate_post_synth,2)
	$(call simulate_post_synth,3)
	$(call simulate_post_synth,4)
	$(call simulate_post_synth,5)
	$(call simulate_post_synth,6)
	$(call simulate_post_synth,7)
