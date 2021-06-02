yosys -import
if { [info procs synth_quicklogic] == {} } { plugin -i ql-qlf }
plugin -i ql-dsp
yosys -import  ;# ingest plugin commands

set TOP "mult16x16"
read_verilog $::env(DESIGN_TOP).v
hierarchy -top $TOP
synth_quicklogic -family qlf_k6n10 -top $TOP
yosys cd $TOP
stat
select -assert-count 1 t:QL_DSP


