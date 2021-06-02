yosys -import
if { [info procs synth_quicklogic] == {} } { plugin -i ql-qlf }
plugin -i ql-dsp
yosys -import  ;# ingest plugin commands

#Logic test for qlf_k4n8 device
read_verilog $::env(DESIGN_TOP).v
hierarchy -top top
yosys proc
equiv_opt -assert -map +/quicklogic/qlf_k4n8_cells_sim.v synth_quicklogic -family qlf_k4n8
design -load postopt
yosys cd top

stat
select -assert-count 9 t:\$lut

design -reset

#Logic test for qlf_k6n10 device
read_verilog $::env(DESIGN_TOP).v
hierarchy -top top
yosys proc
equiv_opt -assert -map +/quicklogic/qlf_k6n10_cells_sim.v synth_quicklogic -family qlf_k6n10
design -load postopt
yosys cd top

stat
select -assert-count 9 t:\$lut
