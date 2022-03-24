yosys -import
if { [info procs get_ports] == {} } { plugin -i design_introspection }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
# Some of F4PGA expects eblifs with only one module.
synth_xilinx -flatten -abc9 -nosrl -noclkbuf -nodsp
help get_ports

set fp [open [test_output_path "get_ports.txt"] "w"]

puts "\n signal_p port"
puts $fp "signal_p port"
puts $fp [get_ports signal_p]

puts "\n clk port"
puts $fp "clk port"
puts $fp [get_ports clk]

puts "\n"
puts { led[0] port}
puts $fp {led[0] port}
puts $fp [get_ports {led[0]}]

puts "\n"
puts { led[1] port}
puts $fp {led[1] port}
puts $fp [get_ports { led[1] }]

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
