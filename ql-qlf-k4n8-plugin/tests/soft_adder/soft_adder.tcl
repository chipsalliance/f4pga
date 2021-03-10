yosys -import
if { [info procs ql-qlf-k4n8] == {} } { plugin -i ql-qlf-k4n8 }
yosys -import  ;# ingest plugin commands

# Equivalence check for adder synthesis
read_verilog -icells -DWIDTH=4 soft_adder.v
hierarchy -check -top adder
yosys proc
equiv_opt -assert -map +/quicklogic/qlf_k4n8_cells_sim.v synth_quicklogic -family qlf_k4n8

design -reset

# Equivalence check for subtractor synthesis
read_verilog -icells -DWIDTH=4 soft_adder.v
hierarchy -check -top subtractor
yosys proc
equiv_opt -assert  -map +/quicklogic/qlf_k4n8_cells_sim.v synth_quicklogic -family qlf_k4n8
