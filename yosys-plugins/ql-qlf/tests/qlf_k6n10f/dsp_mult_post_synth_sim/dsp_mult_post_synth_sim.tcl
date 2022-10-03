yosys -import

if { [info procs ql-qlf-k6n10f] == {} } { plugin -i ql-qlf }
yosys -import  ;

read_verilog $::env(DESIGN_TOP).v
design -save dsp_mult_post_synth_sim

select dsp_mult
select *
synth_quicklogic -family qlf_k6n10f -top dsp_mult
opt_expr -undriven
opt_clean
stat
write_verilog sim/dsp_mult_ports_post_synth.v
select -assert-count 1 t:QL_DSP2_MULT

select -clear
design -load dsp_mult_post_synth_sim
select dsp_mult
select *
synth_quicklogic -family qlf_k6n10f -top dsp_mult -use_dsp_cfg_params
opt_expr -undriven
opt_clean
stat
write_verilog sim/dsp_mult_params_post_synth.v
select -assert-count 1 t:QL_DSP3_MULT
