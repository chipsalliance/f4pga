yosys -import
if { [info procs get_ports] == {} } { plugin -i design_introspection }
if { [info procs read_xdc] == {} } { plugin -i xdc }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v

read_verilog -lib -specify +/xilinx/cells_sim.v
read_verilog -lib +/xilinx/cells_xtra.v
read_verilog -lib [file dirname $::env(DESIGN_TOP)]/cells_xtra.v

hierarchy -check -top top

# -flatten is used to ensure that the output eblif has only one module.
# Some of F4PGA expects eblifs with only one module.
synth_xilinx -flatten -abc9 -nosrl -noclkbuf -nodsp -run prepare:check

#Read the design constraints
read_xdc -part_json [file dirname $::env(DESIGN_TOP)]/../xc7a35tcsg324-1.json $::env(DESIGN_TOP).xdc

# Clean processes before writing JSON.
yosys proc

# Write the design in JSON format.
write_json [test_output_path "io_loc_pairs.json"]
write_blif -param [test_output_path "io_loc_pairs.eblif"]
