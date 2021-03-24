yosys -import
if { [info procs synth_quicklogic] == {} } { plugin -i ql-qlf-k6n10 }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
design -save read

# DFF
hierarchy -top my_dff
yosys proc
equiv_opt -assert -map +/quicklogic/qlf_k6n10_cells_sim.v synth_quicklogic -top my_dff
design -load postopt
yosys cd my_dff
stat
select -assert-count 1 t:dff
