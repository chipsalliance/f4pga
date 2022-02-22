yosys -import
if { [info procs quicklogic_eqn] == {} } { plugin -i ql-qlf}
yosys -import  ;# ingest plugin commands

read_verilog dsp_mult.v
design -save read

set TOP "mult_16x16"
design -load read
hierarchy -top $TOP
synth_quicklogic -family qlf_k6n10f -top $TOP
yosys cd $TOP
select -assert-count 1 t:dsp_t1_20x18x64

set TOP "mult_20x18"
design -load read
hierarchy -top $TOP
synth_quicklogic -family qlf_k6n10f -top $TOP
yosys cd $TOP
select -assert-count 1 t:dsp_t1_20x18x64

set TOP "mult_8x8"
design -load read
hierarchy -top $TOP
synth_quicklogic -family qlf_k6n10f -top $TOP
yosys cd $TOP
select -assert-count 1 t:dsp_t1_10x9x32

set TOP "mult_10x9"
design -load read
hierarchy -top $TOP
synth_quicklogic -family qlf_k6n10f -top $TOP
yosys cd $TOP
select -assert-count 1 t:dsp_t1_10x9x32

