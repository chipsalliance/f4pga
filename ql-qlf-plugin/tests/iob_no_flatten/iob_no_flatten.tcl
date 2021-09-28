yosys -import
if { [info procs quicklogic_eqn] == {} } { plugin -i ql-qlf}
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v

synth_quicklogic -family qlf_k4n8 -top my_top
yosys stat
yosys cd my_top
select -assert-count 2 t:dffsr

design -reset

read_verilog $::env(DESIGN_TOP).v

synth_quicklogic -family qlf_k6n10 -top my_top
yosys stat
yosys cd my_top
select -assert-count 2 t:dff
