yosys -import
if { [info procs synth_quicklogic] == {} } { plugin -i ql-qlf-k6n10 }
yosys -import  ;# ingest plugin commands

# Equivalence check for adder synthesis
read_verilog -icells -DWIDTH=4 $::env(DESIGN_TOP).v
hierarchy -check -top hard_adder
yosys proc
equiv_opt -assert -map +/quicklogic/qlf_k6n10_cells_sim.v synth_quicklogic -family qlf_k6n10

design -reset

#TODO: Fix equivalence
# Equivalence check for subtractor synthesis
#read_verilog -icells -DWIDTH=4 $::env(DESIGN_TOP).v
#hierarchy -check -top subtractor
#yosys proc
#equiv_opt -assert  -map +/quicklogic/qlf_k6n10_cells_sim.v synth_quicklogic -family qlf_k6n10
