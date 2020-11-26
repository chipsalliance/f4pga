yosys -import
plugin -i design_introspection
#Import the commands from the plugins to the tcl interpreter
yosys -import

read_verilog get_cells.v
# Some of symbiflow expects eblifs with only one module.
synth_xilinx -flatten -abc9 -nosrl -noclkbuf -nodsp


set fp [open "get_cells.txt" "w"]

puts "\n*inter* cells quiet"
puts $fp "\n*inter* cells quiet"
puts $fp [get_cells -quiet *inter*]

puts "\n*inter* cells"
puts $fp "\n*inter* cells"
puts $fp [get_cells *inter*]

puts "\n*inter* cells with invalid filter expression"
puts $fp "\n*inter* cells with invalid filter expression"
puts $fp [get_cells -filter {mr_ff != true} *inter* ]

puts "\nFiltered cells"
puts $fp "\nFiltered cells"
puts $fp [get_cells -filter {mr_ff == true || async_reg == true && dont_touch == true} ]

puts "\nAll cells"
puts $fp "\nAll cells"
puts $fp [get_cells]

close $fp
