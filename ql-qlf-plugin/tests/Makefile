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

# The bram test will be enable in a future PR after it's been fixed.

TESTS = consts \
	dffs \
	latches \
	shreg \
	iob_no_flatten \
	full_adder \
	mac_unit \
	multiplier \
	logic \
	mux \
	tribuf \
	fsm \
	pp3_bram \
    qlf_k6n10f/dsp_mult \
    qlf_k6n10f/dsp_simd \
    qlf_k6n10f/dsp_macc \
#	qlf_k6n10_bram \

SIM_TESTS = \
    qlf_k6n10f/sim_dsp_mult \
    qlf_k6n10f/sim_dsp_mult_r \
    qlf_k6n10f/sim_dsp_fir \
    qlf_k6n10f/sim_tc36fifo

# Those tests perform synthesis and simulation of synthesis results
POST_SYNTH_SIM_TESTS = \
    qlf_k6n10f/bram_tdp \
    qlf_k6n10f/bram_sdp

include $(shell pwd)/../../Makefile_test.common

consts_verify = true
dffs_verify = true
shreg_verify = true
iob_no_flatten_verify = true
latches_verify = true
full_adder_verify = true
mac_unit_verify = true
multiplier_verify = true
logic_verify = true
mux_verify = true
tribuf_verify = true
fsm_verify = true
pp3_bram_verify = true
qlf_k6n10f-dsp_mult_verify = true
qlf_k6n10f-dsp_simd_verify = true
qlf_k6n10f-dsp_macc_verify = true
#qlf_k6n10_bram_verify = true
