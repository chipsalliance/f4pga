NAME = ql-qlf
SOURCES = synth_quicklogic.cc
include ../Makefile_plugin.common

COMMON		= common
QLF_K4N8_DIR 	= ql-qlf-k4n8
QLF_K6N10_DIR 	= ql-qlf-k6n10
VERILOG_MODULES = $(COMMON)/cells_sim.v 			\
		  $(QLF_K4N8_DIR)/qlf_k4n8_arith_map.v 		\
		  $(QLF_K4N8_DIR)/qlf_k4n8_cells_sim.v 		\
		  $(QLF_K4N8_DIR)/qlf_k4n8_ffs_map.v 		\
		  $(QLF_K6N10_DIR)/qlf_k6n10_arith_map.v 	\
		  $(QLF_K6N10_DIR)/qlf_k6n10_brams_map.v 	\
		  $(QLF_K6N10_DIR)/qlf_k6n10_brams.txt 		\
		  $(QLF_K6N10_DIR)/qlf_k6n10_cells_sim.v 	\
		  $(QLF_K6N10_DIR)/qlf_k6n10_ffs_map.v 		\
		  $(QLF_K6N10_DIR)/qlf_k6n10_dsp_map.v 		\
		  $(QLF_K6N10_DIR)/qlf_k6n10_lut_map.v

install_modules: $(VERILOG_MODULES)
	$(foreach f,$^,install -D $(f) $(DATA_DIR)/quicklogic/$(notdir $(f));)

install: install_modules
