TESTS = generic

all: $(TESTS)

generic:
	yosys -p "plugin -i ../ql-iob.so; read_verilog design.v; synth_quicklogic ; stat; quicklogic_iob design.pcf pinmap.csv; stat; write_blif -attr -param -cname design.eblif"
	@echo $@ PASS
