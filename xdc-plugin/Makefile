NAME = xdc
SOURCES = xdc.cc
include ../Makefile_plugin.common
VERILOG_MODULES = BANK.v

install_modules: $(VERILOG_MODULES)
	install -D $< $(PLUGINS_DIR)/fasm_extra_modules/$<

install: install_modules
