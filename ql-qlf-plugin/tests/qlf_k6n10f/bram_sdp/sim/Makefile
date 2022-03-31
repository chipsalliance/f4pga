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

TESTBENCH = bram_sdp_tb.v
POST_SYNTH = bram_sdp_36x1024_post_synth bram_sdp_32x1024_post_synth bram_sdp_18x2048_post_synth bram_sdp_16x2048_post_synth bram_sdp_9x4096_post_synth bram_sdp_8x4096_post_synth bram_sdp_4x8192_post_synth bram_sdp_2x16384_post_synth bram_sdp_1x32768_post_synth
ADDR_WIDTH = 10 10 11 11 12 12 13 14 15
DATA_WIDTH = 36 32 18 16 9 8 4 2 1
TOP = BRAM_SDP_36x1024 BRAM_SDP_32x1024 BRAM_SDP_18x2048 BRAM_SDP_16x2048 BRAM_SDP_9x4096 BRAM_SDP_8x4096 BRAM_SDP_4x8192 BRAM_SDP_2x16384 BRAM_SDP_1x32768
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

# FIXME: $(call simulate_post_synth,5)
sim:
	$(call simulate_post_synth,1)
	$(call simulate_post_synth,2)
	$(call simulate_post_synth,3)
	$(call simulate_post_synth,4)
	$(call simulate_post_synth,6)
	$(call simulate_post_synth,7)
	$(call simulate_post_synth,8)
	$(call simulate_post_synth,9)
