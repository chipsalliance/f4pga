yosys -import
if { [info procs read_sdc] == {} } { plugin -i sdc }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
# Some of F4PGA expects eblifs with only one module.
synth_xilinx -flatten -abc9 -nosrl -noclkbuf -nodsp

# -to inter_wire net
set_false_path -to inter_wire

# -from clk net (quiet)
set_false_path -quiet -from clk

# -from clk to bottom_inst/I
set_false_path -from clk -to bottom_inst.I

# -through bottom_inst/I
set_false_path -through bottom_inst.I

write_sdc [test_output_path "set_false_path.sdc"]
