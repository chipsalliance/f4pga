NAME = ql-qlf-k6n10
SOURCES = synth_quicklogic.cc
include ../Makefile_plugin.common

VERILOG_MODULES = cells_sim.v qlf_k6n10_arith_map.v qlf_k6n10_brams_map.v qlf_k6n10_brams.txt qlf_k6n10_cells_sim.v qlf_k6n10_ffs_map.v qlf_k6n10_lut_map.v

install_modules: $(VERILOG_MODULES)
	$(foreach f,$^,install -D $(f) $(DATA_DIR)/quicklogic/$(f);)
install: install_modules
