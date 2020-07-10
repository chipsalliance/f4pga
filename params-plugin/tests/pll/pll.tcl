yosys -import
plugin -i xdc
plugin -i params
#Import the commands from the plugins to the tcl interpreter
yosys -import

read_verilog -specify -lib -D_EXPLICIT_CARRY +/xilinx/cells_sim.v
read_verilog -lib +/xilinx/cells_xtra.v
hierarchy -check -auto-top
set phase [getparam CLKOUT2_PHASE top/PLLE2_ADV]
puts "Phase before: $phase"
setparam -set CLKOUT2_PHASE [expr $phase * 1000] top/PLLE2_ADV
puts "Phase after: [getparam CLKOUT2_PHASE top/PLLE2_ADV]"
# Start flow after library reading
synth_xilinx -vpr -flatten -abc9 -nosrl -noclkbuf -nodsp -iopad -run prepare:check

# Map Xilinx tech library to 7-series VPR tech library.
read_verilog -lib ../techmaps/cells_sim.v
techmap -map  ../techmaps/cells_map.v

# opt_expr -undriven makes sure all nets are driven, if only by the $undef
# net.
opt_expr -undriven
opt_clean

setundef -zero -params
stat

# Write the design in JSON format.
write_json $::env(OUT_JSON)
write_blif -attr -param -cname -conn pll.eblif
