yosys -import

if { [info procs ql-qlf-k6n10f] == {} } { plugin -i ql-qlf }
yosys -import  ;

read_verilog $::env(DESIGN_TOP).v
design -save bram_sdp

select BRAM_SDP_32x512
select *
synth_quicklogic -family qlf_k6n10f -top BRAM_SDP_32x512
opt_expr -undriven
opt_clean
stat
write_verilog sim/bram_sdp_32x512_post_synth.v
select -assert-count 1 t:TDP36K

select -clear
design -load bram_sdp
select BRAM_SDP_16x1024
select *
synth_quicklogic -family qlf_k6n10f -top BRAM_SDP_16x1024
opt_expr -undriven
opt_clean
stat
write_verilog sim/bram_sdp_16x1024_post_synth.v
select -assert-count 1 t:TDP36K

select -clear
design -load bram_sdp
select BRAM_SDP_8x2048
select *
synth_quicklogic -family qlf_k6n10f -top BRAM_SDP_8x2048
opt_expr -undriven
opt_clean
stat
write_verilog sim/bram_sdp_8x2048_post_synth.v
select -assert-count 1 t:TDP36K

select -clear
design -load bram_sdp
select BRAM_SDP_4x4096
select *
synth_quicklogic -family qlf_k6n10f -top BRAM_SDP_4x4096
opt_expr -undriven
opt_clean
stat
write_verilog sim/bram_sdp_4x4096_post_synth.v
select -assert-count 1 t:TDP36K

