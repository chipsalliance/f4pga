yosys -import
if { [info procs synth_quicklogic] == {} } { plugin -i ql-qlf-k4n8 }
yosys -import ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
synth_quicklogic -top top
stat
select -assert-count 8 t:sh_dff
