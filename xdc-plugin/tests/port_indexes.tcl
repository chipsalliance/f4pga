yosys -import
plugin -i xdc
#Import the commands from the plugins to the tcl interpreter
yosys -import

# -flatten is used to ensure that the output eblif has only one module.
# Some of symbiflow expects eblifs with only one module.
synth_xilinx -vpr -flatten -abc9 -nosrl -noclkbuf -nodsp

if {[info procs unknown] != ""} {
	rename unknown ""
}
proc unknown args {puts "'unknown' proc command handler"}
if {[catch {invalid command}]} {
	error "Command should be handled by the 'unknown' proc"
}
#Read the design constraints
read_xdc -part_json $::env(PART_JSON) $::env(INPUT_XDC_FILE)

if {[catch {invalid command}]} {
	error "Command should be handled by the 'unknown' proc"
}

# Write the design in JSON format.
write_json $::env(OUT_JSON)
