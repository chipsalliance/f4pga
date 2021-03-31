yosys -import
if { [info procs synth_quicklogic] == {} } { plugin -i ql-qlf }
yosys -import  ;# ingest plugin commands

#read_verilog $::env(DESIGN_TOP).v
read_verilog latches.v
design -save read

# LATCHP
synth_quicklogic -family qlf_k4n8 -top latchp
yosys cd latchp
stat
select -assert-count 1 t:\$_DLATCH_P_

# LATCHN
design -load read
synth_quicklogic -family qlf_k6n10 -top latchn
yosys cd latchn
stat
select -assert-count 1 t:\$_DLATCH_N_

# LATCHP test for qlf_k6n10 family
design -load read
synth_quicklogic -family qlf_k4n8 -top latchp_noinit
yosys cd latchp_noinit
stat
select -assert-count 1 t:\$_DLATCH_P_

