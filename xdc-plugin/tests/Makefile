# Copyright (C) 2020-2021  The SymbiFlow Authors.
#
# Use of this source code is governed by a ISC-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/ISC
#
# SPDX-License-Identifier:ISC

# counter - basic test for IOSTANDARD, SLEW, DRIVE, IN_TERM properties
# counter-dict - basic test using XDC -dict for IOSTANDARD, SLEW, DRIVE, IN_TERM properties
# port_indexes - like counter but bus port indices are passes without curly braces
# io_loc_pairs - test for LOC property being set on IOBUFs as the IO_LOC_PAIRS parameter
# minilitex_ddr_arty - litex design with more types of IOBUFS including differential
# package_pins - test for PACKAGE_PIN property being set on IOBUFs as the IO_LOC_PAIRS parameter
TESTS = counter \
	counter-dict \
	port_indexes \
	io_loc_pairs \
	minilitex_ddr_arty \
	package_pins

include $(shell pwd)/../../Makefile_test.common

json_test = python compare_output_json.py --json $(1)/$(1).json --golden $(1)/$(1).golden.json

define json_update =
$(1)_update_json:
	python compare_output_json.py --json $(1)/$(1).json --golden $(1)/$(1).golden.json --update
endef

counter_verify = $(call json_test,counter)
counter-dict_verify = $(call json_test,counter-dict)
port_indexes_verify = $(call json_test,port_indexes) && test $$(grep "'unknown' proc command handler" port_indexes/port_indexes.txt | wc -l) -eq 2
io_loc_pairs_verify = $(call json_test,io_loc_pairs)
minilitex_ddr_arty_verify = $(call json_test,minilitex_ddr_arty)
package_pins_verify = $(call json_test,package_pins)
