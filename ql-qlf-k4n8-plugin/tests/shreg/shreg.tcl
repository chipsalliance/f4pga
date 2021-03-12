yosys -import
if { [info procs ql-qlf-k4n8] == {} } { plugin -i ql-qlf-k4n8 }
yosys -import ;# ingest plugin commands

read_verilog shreg.v
synth_quicklogic -top top
stat
select -assert-count 8 t:sh_dff
