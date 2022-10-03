yosys -import
if { [info procs get_cells] == {} } { plugin -i design_introspection }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
# Some of F4PGA expects eblifs with only one module.
synth_xilinx -flatten -abc9 -nosrl -noclkbuf -nodsp


set fp [open [test_output_path "get_cells.txt"] "w"]

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
