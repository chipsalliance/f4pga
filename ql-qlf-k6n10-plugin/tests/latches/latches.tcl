yosys -import
if { [info procs synth_quicklogic] == {} } { plugin -i ql-qlf-k6n10 }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v

design -save read

# LATCHP
synth_quicklogic -top latchp
yosys cd latchp
stat
select -assert-count 1 t:\$_DLATCH_P_


