yosys -import

if { [info procs ql-qlf-k6n10f] == {} } { plugin -i ql-qlf }
yosys -import  ;

read_verilog $::env(DESIGN_TOP).v
design -save dsp_simd

select simd_mult
select *
synth_quicklogic -family qlf_k6n10f -top simd_mult
opt_expr -undriven
opt_clean
stat
write_verilog sim/simd_mult_post_synth.v
select -assert-count 1 t:QL_DSP2_MULT

select -clear
design -load dsp_simd
select simd_mult_explicit_ports
select *
synth_quicklogic -family qlf_k6n10f -top simd_mult_explicit_ports
opt_expr -undriven
opt_clean
stat
write_verilog sim/simd_mult_explicit_ports_post_synth.v
select -assert-count 1 t:QL_DSP2_MULT_REGIN

select -clear
design -load dsp_simd
select simd_mult_explicit_params
select *
synth_quicklogic -family qlf_k6n10f -top simd_mult_explicit_params -use_dsp_cfg_params
opt_expr -undriven
opt_clean
stat
write_verilog sim/simd_mult_explicit_params_post_synth.v
select -assert-count 1 t:QL_DSP3_MULT_REGIN
