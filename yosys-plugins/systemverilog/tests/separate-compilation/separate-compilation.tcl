yosys -import
if { [info procs read_uhdm] == {} } { plugin -i systemverilog }
yosys -import  ;# ingest plugin commands

set TMP_DIR /tmp
if { [info exists ::env(TMPDIR) ] } {
  set TMP_DIR $::env(TMPDIR)
}

# Testing simple round-trip
read_systemverilog -odir $TMP_DIR/separate-compilation-test -defer $::env(DESIGN_TOP)-pkg.sv
read_systemverilog -odir $TMP_DIR/separate-compilation-test -defer $::env(DESIGN_TOP)-buf.sv
read_systemverilog -odir $TMP_DIR/separate-compilation-test -defer $::env(DESIGN_TOP).v
read_systemverilog -odir $TMP_DIR/separate-compilation-test -link
hierarchy
write_verilog
