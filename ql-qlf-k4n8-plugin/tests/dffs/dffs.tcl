yosys -import
if { [info procs synth_quicklogic] == {} } { plugin -i ql-qlf-k4n8 }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
design -save read

# DFF
hierarchy -top my_dff
yosys proc
equiv_opt -assert -map +/quicklogic/qlf_k4n8_cells_sim.v synth_quicklogic -top my_dff
design -load postopt
yosys cd my_dff
stat
select -assert-count 1 t:dff

# DFFR (posedge RST)
design -load read
synth_quicklogic -top my_dffr_p
yosys cd my_dffr_p
stat
select -assert-count 1 t:dffr
select -assert-count 1 t:\$lut

# DFFR (negedge RST)
design -load read
synth_quicklogic -top my_dffr_n
yosys cd my_dffr_n
stat
select -assert-count 1 t:dffr

# DFFS (posedge SET)
design -load read
synth_quicklogic -top my_dffs_p
yosys cd my_dffs_p
stat
select -assert-count 1 t:dffs
select -assert-count 1 t:\$lut

# DFFS (negedge SET)
design -load read
synth_quicklogic -top my_dffs_n
yosys cd my_dffs_n
stat
select -assert-count 1 t:dffs
