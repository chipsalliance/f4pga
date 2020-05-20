yosys -import
plugin -i xdc
#Import the commands from the plugins to the tcl interpreter
yosys -import
# -flatten is used to ensure that the output eblif has only one module.
# Some of symbiflow expects eblifs with only one module.
synth_xilinx -vpr -flatten -abc9 -nosrl -noclkbuf -nodsp

#Read the design constraints
read_xdc -part_json $::env(PART_JSON) $::env(INPUT_XDC_FILE)

# Write the design in JSON format.
write_json $::env(OUT_JSON)
