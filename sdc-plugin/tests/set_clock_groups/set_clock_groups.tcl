yosys -import
plugin -i sdc
#Import the commands from the plugins to the tcl interpreter
yosys -import

read_verilog set_clock_groups.v
# Some of symbiflow expects eblifs with only one module.
synth_xilinx -vpr -flatten -abc9 -nosrl -noclkbuf -nodsp

set_clock_groups -group clk1 clk2
set_clock_groups -asynchronous -group clk3 clk4
set_clock_groups -group clk5 clk6 -logically_exclusive
set_clock_groups -group clk7 clk8 -physically_exclusive -group clk9 clk10
set_clock_groups -quiet -group clk11 clk12 -asynchronous -group clk13 clk14

write_sdc set_clock_groups.sdc
