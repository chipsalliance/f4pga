NAME = ql-qlf-k4n8
SOURCES = synth_quicklogic.cc
include ../Makefile_plugin.common

VERILOG_MODULES = cells_sim.v qlf_k4n8_arith_map.v qlf_k4n8_cells_sim.v qlf_k4n8_ffs_map.v

install_modules: $(VERILOG_MODULES)
	$(foreach f,$^,install -D $(f) $(DATA_DIR)/quicklogic/$(f);)

install: install_modules
