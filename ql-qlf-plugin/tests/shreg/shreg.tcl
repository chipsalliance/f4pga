yosys -import
if { [info procs synth_quicklogic] == {} } { plugin -i ql-qlf }
plugin -i ql-dsp
yosys -import ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
synth_quicklogic -family qlf_k4n8 -top top
stat
select -assert-count 8 t:sh_dff
