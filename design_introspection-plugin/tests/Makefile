# Copyright (C) 2020-2021  The SymbiFlow Authors.
#
# Use of this source code is governed by a ISC-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/ISC
#
# SPDX-License-Identifier:ISC

TESTS = get_nets \
	get_ports \
	get_cells \
	get_pins \
	get_count \
	selection_to_tcl_list

UNIT_TESTS = trim_name

include $(shell pwd)/../../Makefile_test.common

get_nets_verify = $(call diff_test,get_nets,txt)
get_ports_verify = $(call diff_test,get_ports,txt)
get_cells_verify = $(call diff_test,get_cells,txt)
get_pins_verify = $(call diff_test,get_pins,txt)
get_count_verify = true
selection_to_tcl_list_verify = $(call diff_test,selection_to_tcl_list,txt)
