yosys -import
if { [info procs synth_quicklogic] == {} } { plugin -i ql-qlf }
plugin -i ql-dsp
yosys -import  ;# ingest plugin commands

# Equivalence check for adder synthesis for qlf-k4n8
read_verilog -icells -DWIDTH=4 $::env(DESIGN_TOP).v
hierarchy -check -top full_adder
yosys proc
equiv_opt -assert -map +/quicklogic/qlf_k4n8_cells_sim.v synth_quicklogic -family qlf_k4n8

design -reset

# Equivalence check for subtractor synthesis
read_verilog -icells -DWIDTH=4 $::env(DESIGN_TOP).v
hierarchy -check -top subtractor
yosys proc
equiv_opt -assert  -map +/quicklogic/qlf_k4n8_cells_sim.v synth_quicklogic -family qlf_k4n8

design -reset
# Equivalence check for adder synthesis for qlf-k6n10
read_verilog -icells -DWIDTH=4 $::env(DESIGN_TOP).v
hierarchy -check -top full_adder
yosys proc
equiv_opt -assert -map +/quicklogic/qlf_k6n10_cells_sim.v synth_quicklogic -family qlf_k6n10

design -reset

#TODO: Fix equivalence check for substractor design with qlf_k6n10 device

## Equivalence check for subtractor synthesis
#read_verilog -icells -DWIDTH=4 $::env(DESIGN_TOP).v
#hierarchy -check -top subtractor
#yosys proc
#equiv_opt -assert  -map +/quicklogic/qlf_k6n10_cells_sim.v synth_quicklogic -family qlf_k6n10
