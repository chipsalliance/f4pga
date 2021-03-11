yosys -import
if { [info procs ql-qlf-k4n8] == {} } { plugin -i ql-qlf-k4n8 }
yosys -import  ;# ingest plugin commands

read_verilog dffs.v
design -save read

# qlf_k4n8 supports only DFF w/o set and reset
hierarchy -top my_dff
yosys proc
equiv_opt -assert -map +/quicklogic/qlf_k4n8_cells_sim.v synth_quicklogic -top my_dff
design -load postopt
yosys cd my_dff
stat
select -assert-count 1 t:*_DFF_P_

