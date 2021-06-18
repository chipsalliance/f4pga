# Copyright (C) 2020-2021  The SymbiFlow Authors.
#
# Use of this source code is governed by a ISC-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/ISC
#
# SPDX-License-Identifier:ISC

# abc9 - test that abc9.D is correctly set after importing a clock.
# counter, counter2, pll - test buffer and clock divider propagation
# set_false_path - test the set_false_path command
# set_max_delay - test the set_max_delay command
# set_clock_groups - test the set_clock_groups command
# restore_from_json - test clock propagation when design restored from json instead verilog
# period_check - test if the clock propagation fails if a clock wire is missing the PERIOD attribute
# waveform_check - test if the WAVEFORM attribute value is correct on wire
# period_format_check - test if PERIOD attribute value is correct on wire

TESTS = abc9 \
	counter \
	counter2 \
	pll \
	pll_div \
	pll_fbout_phase \
	pll_approx_equal \
	pll_dangling_wires \
	pll_propagated \
	set_false_path \
	set_max_delay \
	set_clock_groups \
	restore_from_json \
	period_check \
	waveform_check \
	period_format_check \
	get_clocks

UNIT_TESTS = escaping

include $(shell pwd)/../../Makefile_test.common

abc9_verify = true
counter_verify = $(call diff_test,counter,sdc) && $(call diff_test,counter,txt)
counter2_verify = $(call diff_test,counter2,sdc) && $(call diff_test,counter2,txt)
pll_verify = $(call diff_test,pll,sdc)
pll_div_verify = $(call diff_test,pll_div,sdc)
pll_fbout_phase_verify = $(call diff_test,pll_fbout_phase,sdc)
pll_approx_equal_verify = $(call diff_test,pll_approx_equal,sdc)
pll_dangling_wires_verify = $(call diff_test,pll_dangling_wires,sdc)
pll_propagated_verify = $(call diff_test,pll_propagated,sdc)
set_false_path_verify = $(call diff_test,set_false_path,sdc)
set_max_delay_verify = $(call diff_test,set_max_delay,sdc)
set_clock_groups_verify = $(call diff_test,set_clock_groups,sdc)
restore_from_json_verify = diff restore_from_json/restore_from_json_1.sdc restore_from_json/restore_from_json_2.sdc
period_check_verify = true
period_check_negative = 1
waveform_check_verify = true
waveform_check_negative = 1
period_format_check_verify = true
period_format_check_negative = 1
get_clocks_verify = $(call diff_test,get_clocks,txt)
