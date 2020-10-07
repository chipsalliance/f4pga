yosys -import
plugin -i xdc
#Import the commands from the plugins to the tcl interpreter
yosys -import

read_verilog $::env(DESIGN_TOP).v

# -flatten is used to ensure that the output eblif has only one module.
# Some of symbiflow expects eblifs with only one module.
synth_xilinx -vpr -flatten -abc9 -nosrl -noclkbuf -nodsp

#Read the design constraints
read_xdc -part_json ../xc7a35tcsg324-1.json $::env(DESIGN_TOP).xdc

# Write the design in JSON format.
write_json $::env(DESIGN_TOP).json
