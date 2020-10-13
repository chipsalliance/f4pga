yosys -import
plugin -i design_introspection
#Import the commands from the plugins to the tcl interpreter
yosys -import

read_verilog get_pins.v
# Some of symbiflow expects eblifs with only one module.
synth_xilinx -vpr -flatten -abc9 -nosrl -noclkbuf -nodsp


set fp [open "get_pins.txt" "w"]

puts "\n*inter* pins quiet"
puts $fp "\n*inter* pins quiet"
puts $fp [get_pins -quiet OBUF_6/I]

puts "\n*inter* pins"
puts $fp "\n*inter* pins"
puts $fp [get_pins OBUF_6/I]

puts "\n*inter* pins with invalid filter expression"
puts $fp "\n*inter* pins with invalid filter expression"
puts $fp [get_pins -filter {mr_ff != true} *inter*/I ]

puts "\nFiltered pins"
puts $fp "\nFiltered pins"
puts $fp [get_pins -filter {dont_touch == true || async_reg == true && mr_ff == true} *OBUF*/I ]

close $fp
