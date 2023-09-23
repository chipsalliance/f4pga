yosys -import
if { [info procs quicklogic_eqn] == {} } { plugin -i ql-qlf }
yosys -import ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
synth_quicklogic -family qlf_k4n8 -top top
stat
select -assert-count 8 t:sh_dff

design -reset

read_verilog $::env(DESIGN_TOP).v
synth_quicklogic -family qlf_k6n10f -top top
stat
select -assert-count 8 t:sh_dff

