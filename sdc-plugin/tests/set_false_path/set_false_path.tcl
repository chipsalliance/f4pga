yosys -import
plugin -i sdc
#Import the commands from the plugins to the tcl interpreter
yosys -import

read_verilog $::env(DESIGN_TOP).v
# Some of symbiflow expects eblifs with only one module.
synth_xilinx -vpr -flatten -abc9 -nosrl -noclkbuf -nodsp

# -to inter_wire net
set_false_path -to inter_wire

# -from clk net (quiet)
set_false_path -quiet -from clk

# -from clk to bottom_inst/I
set_false_path -from clk -to bottom_inst.I

# -through bottom_inst/I
set_false_path -through bottom_inst.I

write_sdc $::env(DESIGN_TOP).sdc
