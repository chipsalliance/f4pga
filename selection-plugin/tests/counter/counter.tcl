yosys -import
plugin -i selection

# Import the commands from the plugins to the tcl interpreter
yosys -import

read_verilog counter.v
read_verilog -specify -lib -D_EXPLICIT_CARRY +/xilinx/cells_sim.v
read_verilog -lib +/xilinx/cells_xtra.v
hierarchy -check -auto-top

puts "List: [selection_to_tcl_list w:*]"

# Write the selection to file
set fh [open counter.txt w]
set selection_list [selection_to_tcl_list w:*]
puts $fh $selection_list
close $fh
