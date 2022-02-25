yosys -import
if { [info procs quicklogic_eqn] == {} } { plugin -i ql-qlf}
yosys -import  ;# ingest plugin commands

read_verilog dsp_macc.v
design -save read

set TOP "macc_simple"
design -load read
hierarchy -top $TOP
synth_quicklogic -family qlf_k6n10f -top $TOP
yosys cd $TOP
select -assert-count 1 t:dsp_t1_10x9x32
select -assert-count 1 t:*

set TOP "macc_simple_clr"
design -load read
hierarchy -top $TOP
synth_quicklogic -family qlf_k6n10f -top $TOP
yosys cd $TOP
select -assert-count 1 t:dsp_t1_10x9x32
select -assert-count 1 t:\$lut
select -assert-count 2 t:*

set TOP "macc_simple_arst"
design -load read
hierarchy -top $TOP
synth_quicklogic -family qlf_k6n10f -top $TOP
yosys cd $TOP
select -assert-count 1 t:dsp_t1_10x9x32
select -assert-count 1 t:*

set TOP "macc_simple_arst_clr"
design -load read
hierarchy -top $TOP
synth_quicklogic -family qlf_k6n10f -top $TOP
yosys cd $TOP
select -assert-count 1 t:dsp_t1_10x9x32
select -assert-count 1 t:\$lut
select -assert-count 2 t:*

