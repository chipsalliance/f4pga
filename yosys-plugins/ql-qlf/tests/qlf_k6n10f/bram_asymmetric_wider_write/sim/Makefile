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

TESTBENCH = bram_asymmetric_wider_write_tb.v
POST_SYNTH = spram_16x2048_8x4096_post_synth spram_16x1024_8x2048_post_synth spram_32x1024_8x4096_post_synth spram_32x1024_16x2048_post_synth
READ_ADDR_WIDTH = 12 11 12 11
WRITE_ADDR_WIDTH = 11 10 10 10
READ_DATA_WIDTH = 8 8 8 16
WRITE_DATA_WIDTH = 16 16 32 32
TOP = spram_16x2048_8x4096 spram_16x1024_8x2048 spram_32x1024_8x4096 spram_32x1024_16x2048
READ_ADDR_DEFINES = $(foreach awidth, $(READ_ADDR_WIDTH),-DREAD_ADDR_WIDTH="$(awidth)")
WRITE_ADDR_DEFINES = $(foreach awidth, $(WRITE_ADDR_WIDTH),-DWRITE_ADDR_WIDTH="$(awidth)")
READ_DATA_DEFINES = $(foreach dwidth, $(READ_DATA_WIDTH),-DREAD_DATA_WIDTH="$(dwidth)")
WRITE_DATA_DEFINES = $(foreach dwidth, $(WRITE_DATA_WIDTH),-DWRITE_DATA_WIDTH="$(dwidth)")
TOP_DEFINES = $(foreach top, $(TOP),-DTOP="$(top)")
VCD_DEFINES = $(foreach vcd, $(POST_SYNTH),-DVCD="$(vcd).vcd")

SIM_LIBS = $(shell find ../../../../qlf_k6n10f -name "*.v" -not -name "*_map.v")

define simulate_post_synth
	@iverilog  -vvvv -g2005 $(word $(1),$(READ_ADDR_DEFINES)) $(word $(1),$(WRITE_ADDR_DEFINES)) $(word $(1),$(READ_DATA_DEFINES)) $(word $(1),$(WRITE_DATA_DEFINES)) $(word $(1),$(TOP_DEFINES)) $(word $(1),$(VCD_DEFINES)) -o $(word $(1),$(POST_SYNTH)).vvp $(word $(1),$(POST_SYNTH)).v $(SIM_LIBS) $(TESTBENCH) > $(word $(1),$(POST_SYNTH)).vvp.log 2>&1
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
