yosys -import
if { [info procs synth_quicklogic] == {} } { plugin -i ql-qlf}
plugin -i ql-dsp
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v

synth_quicklogic -family qlf_k4n8 -top my_top
yosys stat
yosys cd my_top
select -assert-count 2 t:dff

design -reset

read_verilog $::env(DESIGN_TOP).v

synth_quicklogic -family qlf_k6n10 -top my_top
yosys stat
yosys cd my_top
select -assert-count 2 t:dff
