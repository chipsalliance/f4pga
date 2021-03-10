yosys -import
if { [info procs ql-qlf-k4n8] == {} } { plugin -i ql-qlf-k4n8 }
yosys -import  ;# ingest plugin commands

read_verilog iob_no_flatten.v

synth_quicklogic -top my_top
yosys stat
yosys cd my_top
select -assert-count 2 t:\$_DFF_P_
