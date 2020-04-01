TESTS = generic

all: $(TESTS)

generic:
	yosys -p "plugin -i ../ql-iob.so; read_verilog design.v; synth_quicklogic -flatten; stat; quicklogic_iob design.pcf pinmap.csv; stat"
	@echo $@ PASS
