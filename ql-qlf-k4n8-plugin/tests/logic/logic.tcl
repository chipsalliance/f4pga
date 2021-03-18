yosys -import
if { [info procs synth_quicklogic] == {} } { plugin -i ql-qlf-k4n8 }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
hierarchy -top top
yosys proc
equiv_opt -assert -map +/quicklogic/qlf_k4n8_cells_sim.v synth_quicklogic
design -load postopt
yosys cd top

stat
select -assert-count 9 t:\$lut
