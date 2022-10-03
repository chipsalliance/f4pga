yosys -import
if { [info procs read_sdc] == {} } { plugin -i sdc }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
# Some of F4PGA expects eblifs with only one module.
synth_xilinx -flatten -abc9 -nosrl -noclkbuf -nodsp

set_clock_groups -group clk1 clk2
set_clock_groups -asynchronous -group clk3 clk4
set_clock_groups -group clk5 clk6 -logically_exclusive
set_clock_groups -group clk7 clk8 -physically_exclusive -group clk9 clk10
set_clock_groups -quiet -group clk11 clk12 -asynchronous -group clk13 clk14

write_sdc [test_output_path "set_clock_groups.sdc"]
