yosys -import
plugin -i xdc
plugin -i params
#Import the commands from the plugins to the tcl interpreter
yosys -import

read_verilog -specify -lib -D_EXPLICIT_CARRY +/xilinx/cells_sim.v
read_verilog -lib +/xilinx/cells_xtra.v
hierarchy -check -auto-top
set phase [getparam CLKOUT2_PHASE top/PLLE2_ADV_0 top/PLLE2_ADV]
if {[llength $phase] != 2} {
	error "Getparam should return a list with 2 elements"
}
set fp [open "params.txt" "w"]
puts -nonewline $fp "Phase before: "
if {$phase == [list 90 70]} {
	puts $fp "PASS"
} else {
	puts $fp "FAIL"
}
setparam -set CLKOUT2_PHASE [expr [lindex $phase 0] * 1000] top/PLLE2_ADV
set phase [getparam CLKOUT2_PHASE top/PLLE2_ADV_0 top/PLLE2_ADV]
puts -nonewline $fp "Phase after: "
if {$phase == [list 90000 70]} {
	puts $fp "PASS"
} else {
	puts $fp "FAIL"
}
close $fp

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
