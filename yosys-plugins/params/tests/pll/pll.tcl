yosys -import
if { [info procs getparam] == {} } { plugin -i params }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
read_verilog -specify -lib -D_EXPLICIT_CARRY +/xilinx/cells_sim.v
read_verilog -lib +/xilinx/cells_xtra.v
hierarchy -check -auto-top

# Check phase parameter values on bith PLLE2_ADV instances
set reference_phase [list 90 70]
set phase [getparam CLKOUT2_PHASE top/PLLE2_ADV_0 top/PLLE2_ADV]
if {[llength $phase] != 2} {
	error "Getparam should return a list with 2 elements"
}
set fp [open [test_output_path "pll.txt"] "w"]
puts -nonewline $fp "Phase before: "
if {$phase == $reference_phase} {
	puts $fp "PASS"
} else {
	puts $fp "FAIL: $phase != $reference_phase"
}

# Modify the phase parameter value on one of the PLLE2_ADV instances
setparam -set CLKOUT2_PHASE [expr [lindex $phase 0] * 1000] top/PLLE2_ADV

# Verify that the parameter has been correctly updated on the chosen instance
set reference_phase [list 90000 70]
set phase [getparam CLKOUT2_PHASE top/PLLE2_ADV_0 top/PLLE2_ADV]
puts -nonewline $fp "Phase after: "
if {$phase == $reference_phase} {
	puts $fp "PASS"
} else {
	puts $fp "FAIL: $phase != $reference_phase"
}
close $fp

# Start flow after library reading
synth_xilinx -flatten -abc9 -nosrl -noclkbuf -nodsp -iopad -run prepare:check

# Map Xilinx tech library to 7-series VPR tech library.
read_verilog -lib [file dirname $::env(DESIGN_TOP)]/techmaps/cells_sim.v
techmap -map  [file dirname $::env(DESIGN_TOP)]/techmaps/cells_map.v

# opt_expr -undriven makes sure all nets are driven, if only by the $undef
# net.
opt_expr -undriven
opt_clean

setundef -zero -params
stat

# Clean processes before writing JSON.
yosys proc

# Write the design in JSON format.
write_json [test_output_path "pll.json"]
write_blif -attr -param -cname -conn [test_output_path "pll.eblif"]
