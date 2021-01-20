yosys -import
if { [info procs get_ports] == {} } { plugin -i design_introspection }
if { [info procs read_xdc] == {} } { plugin -i xdc }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v

# -flatten is used to ensure that the output eblif has only one module.
# Some of symbiflow expects eblifs with only one module.
synth_xilinx -flatten -abc9 -nosrl -noclkbuf -nodsp

#Read the design constraints
read_xdc -part_json ../xc7a35tcsg324-1.json $::env(DESIGN_TOP).xdc

# Write the design in JSON format.
write_json $::env(DESIGN_TOP).json
