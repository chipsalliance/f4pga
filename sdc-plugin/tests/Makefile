# counter, counter2, pll - test buffer and clock divider propagation
# set_false_path - test the set_false_path command
# set_max_delay - test the set_max_delay command
# set_clock_groups - test the set_clock_groups command

TESTS = counter \
	counter2 \
	pll \
	pll_div \
	pll_fbout_phase \
	pll_approx_equal \
	set_false_path \
	set_max_delay \
	set_clock_groups \
	restore_from_json \
	period_check \
	waveform_check

include $(shell pwd)/../../Makefile_test.common

counter_verify = $(call diff_test,counter,sdc) && $(call diff_test,counter,txt)
counter2_verify = $(call diff_test,counter2,sdc) && $(call diff_test,counter2,txt)
pll_verify = $(call diff_test,pll,sdc)
pll_div_verify = $(call diff_test,pll_div,sdc)
pll_fbout_phase_verify = $(call diff_test,pll_fbout_phase,sdc)
pll_approx_equal_verify = $(call diff_test,pll_approx_equal,sdc)
set_false_path_verify = $(call diff_test,set_false_path,sdc)
set_max_delay_verify = $(call diff_test,set_max_delay,sdc)
set_clock_groups_verify = $(call diff_test,set_clock_groups,sdc)
restore_from_json_verify = diff restore_from_json/restore_from_json_1.sdc restore_from_json/restore_from_json_2.sdc
period_check_verify = true
period_check_negative = 1
waveform_check_verify = true
waveform_check_negative = 1
