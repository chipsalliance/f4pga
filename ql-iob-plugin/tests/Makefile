# Copyright (C) 2020-2021  The SymbiFlow Authors.
#
# Use of this source code is governed by a ISC-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/ISC
#
# SPDX-License-Identifier:ISC

TESTS = sdiomux ckpad

all: clean $(addsuffix /ok,$(TESTS))

clean:
	@find . -name "ok" | xargs rm -rf

sdiomux/ok:
	@$(MAKE) -C sdiomux test
ckpad/ok:
	@$(MAKE) -C ckpad test

.PHONY: all clean
