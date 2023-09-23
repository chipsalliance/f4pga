yosys -import
if { [info procs read_sdc] == {} } { plugin -i sdc }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
read_verilog -specify -lib -D_EXPLICIT_CARRY +/xilinx/cells_sim.v
read_verilog -lib +/xilinx/cells_xtra.v
hierarchy -check -auto-top

# Start flow after library reading
synth_xilinx -flatten -abc9 -nosrl -nodsp -iopad -noclkbuf -run prepare:check

# Read the design timing constraints
read_sdc $::env(DESIGN_TOP).input.sdc

# Propagate the clocks
propagate_clocks

# Write out the SDC file after the clock propagation step
write_sdc [test_output_path "pll_fbout_phase.sdc"]
