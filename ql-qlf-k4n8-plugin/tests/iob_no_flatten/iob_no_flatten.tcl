yosys -import
if { [info procs synth_quicklogic] == {} } { plugin -i ql-qlf-k4n8 }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v

synth_quicklogic -top my_top
yosys stat
yosys cd my_top
select -assert-count 2 t:dff
