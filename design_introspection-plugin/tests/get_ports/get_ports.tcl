yosys -import
plugin -i design_introspection
#Import the commands from the plugins to the tcl interpreter
yosys -import

read_verilog get_ports.v
# Some of symbiflow expects eblifs with only one module.
synth_xilinx -vpr -flatten -abc9 -nosrl -noclkbuf -nodsp
help get_ports

set fp [open "get_ports.txt" "w"]

puts "\nsignal_p port"
puts $fp "signal_p port"
puts $fp [get_ports signal_p]

puts "\nclk port"
puts $fp "clk port"
puts $fp [get_ports clk]

puts {\nled[0] port}
puts $fp {led[0] port}
puts $fp [get_ports {led[0]}]

#puts "\nsignal_* ports quiet"
#puts $fp "signal_* ports quiet"
#puts $fp [get_ports -quiet signal_*]
#
#puts "\nsignal_* ports"
#puts $fp "signal_* ports"
#puts $fp [get_ports signal_*]
#
#puts "\nled ports with filter expression"
#puts $fp "led ports with filter expression"
#puts $fp [get_ports -filter {mr_ff != true} led]
#
#puts "\nFiltered ports"
#puts $fp "Filtered ports"
#puts $fp [get_ports -filter {mr_ff == true || async_reg == true && dont_touch == true} ]
#
#puts "\nAll ports"
#puts $fp "All ports"
#puts $fp [get_ports]

close $fp
