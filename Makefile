# Copyright (C) 2020-2021  The SymbiFlow Authors.
#
# Use of this source code is governed by a ISC-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/ISC
#
# SPDX-License-Identifier:ISC

PLUGIN_LIST := fasm xdc params sdc ql-iob design_introspection integrateinv ql-qlf
PLUGINS := $(foreach plugin,$(PLUGIN_LIST),$(plugin).so)
PLUGINS_INSTALL := $(foreach plugin,$(PLUGIN_LIST),install_$(plugin))
PLUGINS_CLEAN := $(foreach plugin,$(PLUGIN_LIST),clean_$(plugin))
PLUGINS_TEST := $(foreach plugin,$(PLUGIN_LIST),test_$(plugin))

all: plugins

define install_plugin =
$(1).so:
	$$(MAKE) -C $(1)-plugin $$@

install_$(1):
	$$(MAKE) -C $(1)-plugin install

clean_$(1):
	$$(MAKE) -C $(1)-plugin clean

test_$(1):
	@$$(MAKE) --no-print-directory -C $(1)-plugin test
endef

$(foreach plugin,$(PLUGIN_LIST),$(eval $(call install_plugin,$(plugin))))

plugins: $(PLUGINS)

install: $(PLUGINS_INSTALL)

test: $(PLUGINS_TEST)

clean: $(PLUGINS_CLEAN)

CLANG_FORMAT ?= clang-format-8
format:
	find . \( -name "*.h" -o -name "*.cc" \) -and -not -path './third_party/*' -print0 | xargs -0 -P $$(nproc) ${CLANG_FORMAT} -style=file -i

VERIBLE_FORMAT ?= verible-verilog-format
format-verilog:
	find */tests \( -name "*.v" -o -name "*.sv" \) -and -not -path './third_party/*' -print0 | xargs -0 $(VERIBLE_FORMAT) --inplace
