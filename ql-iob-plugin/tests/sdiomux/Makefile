# Copyright (C) 2020-2021  The SymbiFlow Authors.
#
# Use of this source code is governed by a ISC-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/ISC
#
# SPDX-License-Identifier:ISC

# TODO: Integrate this in the Makefile_test.command environment ?
test:
	@yosys -s script.ys -q -q -l $@.log
	@printf "Test %-18s \e[32mPASSED\e[0m @ %s\n" $@ $(CURDIR);
	@touch ok
