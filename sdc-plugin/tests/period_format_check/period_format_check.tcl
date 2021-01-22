yosys -import
if { [info procs read_sdc] == {} } { plugin -i sdc }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
read_verilog -specify -lib -D_EXPLICIT_CARRY +/xilinx/cells_sim.v
read_verilog -lib +/xilinx/cells_xtra.v
hierarchy -check -auto-top
# Start flow after library reading
synth_xilinx -flatten -abc9 -nosrl -nodsp -iopad -run prepare:check

# Propagate the clocks
propagate_clocks

# Write out the SDC file after the clock propagation step
write_sdc [test_output_path "period_format_check.sdc"]
