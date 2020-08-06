yosys -import
plugin -i xdc
plugin -i sdc
# Import the commands from the plugins to the tcl interpreter
yosys -import

read_verilog pll.v
read_verilog -specify -lib -D_EXPLICIT_CARRY +/xilinx/cells_sim.v
read_verilog -lib +/xilinx/cells_xtra.v
hierarchy -check -auto-top

# Start flow after library reading
synth_xilinx -vpr -flatten -abc9 -nosrl -nodsp -iopad -run prepare:check
#
#Read the design timing constraints
set ::env(INPUT_SDC_FILE) pll.sdc
read_sdc $::env(INPUT_SDC_FILE)
propagate_clocks
get_clocks
#return
#
##Read the design constraints
#read_xdc -part_json $::env(PART_JSON) $::env(INPUT_XDC_FILE)
#
## Map Xilinx tech library to 7-series VPR tech library.
#read_verilog -lib ../techmaps/cells_sim.v
#techmap -map  ../techmaps/cells_map.v
#
## opt_expr -undriven makes sure all nets are driven, if only by the $undef
## net.
opt_expr -undriven
opt_clean
#
setundef -zero -params
stat
#
## Write the design in JSON format.
write_json $::env(OUT_JSON)
write_blif -attr -param -cname -conn $::env(OUT_EBLIF)
