yosys -import
if { [info procs quicklogic_eqn] == {} } { plugin -i ql-qlf}
yosys -import  ;# ingest plugin commands

read_verilog dsp_simd.v
design -save read

set TOP "simd_mult"
design -load read
hierarchy -top $TOP
synth_quicklogic -family qlf_k6n10f -top $TOP
yosys cd $TOP
select -assert-count 0 t:dsp_t1_20x18x64
select -assert-count 0 t:dsp_t1_10x9x32
select -assert-count 1 t:QL_DSP2

set TOP "simd_mult_odd"
design -load read
hierarchy -top $TOP
synth_quicklogic -family qlf_k6n10f -top $TOP
yosys cd $TOP
select -assert-count 0 t:dsp_t1_20x18x64
select -assert-count 0 t:dsp_t1_10x9x32
select -assert-count 2 t:QL_DSP2

set TOP "simd_mult_conflict"
design -load read
hierarchy -top $TOP
synth_quicklogic -family qlf_k6n10f -top $TOP
yosys cd $TOP
select -assert-count 0 t:dsp_t1_20x18x64
select -assert-count 0 t:dsp_t1_10x9x32
select -assert-count 2 t:QL_DSP2

