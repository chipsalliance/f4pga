yosys -import
plugin -i design_introspection
#Import the commands from the plugins to the tcl interpreter
yosys -import

read_verilog get_nets.v
# Some of symbiflow expects eblifs with only one module.
synth_xilinx -vpr -flatten -abc9 -nosrl -noclkbuf -nodsp


set fp [open "get_nets.txt" "w"]

puts "\n*inter* nets quiet"
puts $fp "*inter* nets quiet"
puts $fp [get_nets -quiet *inter*]

puts "\n*inter* nets"
puts $fp "*inter* nets"
puts $fp [get_nets *inter*]

puts "\n*inter* nets with invalid filter expression"
puts $fp "*inter* nets with invalid filter expression"
puts $fp [get_nets -filter {mr_ff != true} *inter* ]

puts "\nFiltered nets"
puts $fp "Filtered nets"
puts $fp [get_nets -filter {mr_ff == true || async_reg == true && dont_touch == true} ]

puts "\nAll nets"
puts $fp "All nets"
puts $fp [get_nets]

close $fp
