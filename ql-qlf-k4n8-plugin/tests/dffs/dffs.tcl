yosys -import
if { [info procs ql-qlf-k4n8] == {} } { plugin -i ql-qlf-k4n8 }
yosys -import  ;# ingest plugin commands

read_verilog dffs.v
design -save read

# DFF
hierarchy -top my_dff
yosys proc
equiv_opt -assert -map +/quicklogic/qlf_k4n8_cells_sim.v synth_quicklogic -top my_dff
design -load postopt
yosys cd my_dff
stat
select -assert-count 1 t:*_DFF_P_

# DFFC
design -load read
synth_quicklogic -top my_dffc
yosys cd my_dffc
stat
select -assert-count 1 t:*DFF_P*

# DFFP
design -load read
synth_quicklogic -top my_dffp
yosys cd my_dffp
stat
select -assert-count 1 t:*DFF_P*
