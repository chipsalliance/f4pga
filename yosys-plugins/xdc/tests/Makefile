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

# counter - basic test for IOSTANDARD, SLEW, DRIVE, IN_TERM properties
# counter-dict - basic test using XDC -dict for IOSTANDARD, SLEW, DRIVE, IN_TERM properties
# package_pins-dict-space - basic test for variable whitespace between PACKAGE_PINs and IOSTANDARD
# port_indexes - like counter but bus port indices are passes without curly braces
# io_loc_pairs - test for LOC property being set on IOBUFs as the IO_LOC_PAIRS parameter
# minilitex_ddr_arty - litex design with more types of IOBUFS including differential
# package_pins - test for PACKAGE_PIN property being set on IOBUFs as the IO_LOC_PAIRS parameter
# non_zero_port_indexes - testing IO_LOC_PAIRS for design with non-zero indexed ports
TESTS = counter \
	counter-dict \
	package_pins-dict-space \
	port_indexes \
	io_loc_pairs \
	minilitex_ddr_arty \
	package_pins \
	non_zero_port_indexes

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
package_pins-dict-space_verify = $(call json_test,package_pins-dict-space)
non_zero_port_indexes_verify = $(call json_test,non_zero_port_indexes)
