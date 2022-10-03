yosys -import
if { [info procs read_sdc] == {} } { plugin -i sdc }
if { [info procs get_nets] == {} } { plugin -i design_introspection }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
read_verilog -specify -lib -D_EXPLICIT_CARRY +/xilinx/cells_sim.v
read_verilog -lib +/xilinx/cells_xtra.v
hierarchy -check -auto-top
# Start flow after library reading
synth_xilinx -flatten -abc9 -nosrl -nodsp -iopad -noclkbuf -run prepare:check
#synth_xilinx

# Read the design's timing constraints
read_sdc $::env(DESIGN_TOP).input.sdc

# Propagate the clocks
propagate_clocks

# Write the clocks to file
set fh [open [test_output_path "get_clocks.txt"] w]

puts $fh [get_clocks]

puts $fh [get_clocks -include_generated_clocks]

puts $fh [get_clocks -include_generated_clocks clk2]

puts $fh [get_clocks -of [get_nets clk_int_1 clk1] -include_generated_clocks clk_int_1]

puts $fh [get_clocks -of [get_nets]]

puts $fh [get_clocks -of [concat [get_nets clk2] [get_nets clk_int_1 clk]]]

close $fh
