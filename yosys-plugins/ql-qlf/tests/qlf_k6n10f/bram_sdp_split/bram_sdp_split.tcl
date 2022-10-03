yosys -import

if { [info procs ql-qlf-k6n10f] == {} } { plugin -i ql-qlf }
yosys -import  ;

read_verilog $::env(DESIGN_TOP).v
design -save bram_sdp_split

select BRAM_SDP_SPLIT_2x18x1024
select *
synth_quicklogic -family qlf_k6n10f -top BRAM_SDP_SPLIT_2x18x1024
opt_expr -undriven
opt_clean
stat
write_verilog sim/bram_sdp_split_2x18x1024_post_synth.v
select -assert-count 1 t:TDP36K

select -clear
design -load bram_sdp_split
select BRAM_SDP_SPLIT_2x16x1024
select *
synth_quicklogic -family qlf_k6n10f -top BRAM_SDP_SPLIT_2x16x1024
opt_expr -undriven
opt_clean
stat
write_verilog sim/bram_sdp_split_2x16x1024_post_synth.v
select -assert-count 1 t:TDP36K

select -clear
design -load bram_sdp_split
select BRAM_SDP_SPLIT_2x9x2048
select *
synth_quicklogic -family qlf_k6n10f -top BRAM_SDP_SPLIT_2x9x2048
opt_expr -undriven
opt_clean
stat
write_verilog sim/bram_sdp_split_2x9x2048_post_synth.v
select -assert-count 1 t:TDP36K

select -clear
design -load bram_sdp_split
select BRAM_SDP_SPLIT_2x8x2048
select *
synth_quicklogic -family qlf_k6n10f -top BRAM_SDP_SPLIT_2x8x2048
opt_expr -undriven
opt_clean
stat
write_verilog sim/bram_sdp_split_2x8x2048_post_synth.v
select -assert-count 1 t:TDP36K

select -clear
design -load bram_sdp_split
select BRAM_SDP_SPLIT_2x4x4096
select *
synth_quicklogic -family qlf_k6n10f -top BRAM_SDP_SPLIT_2x4x4096
opt_expr -undriven
opt_clean
stat
write_verilog sim/bram_sdp_split_2x4x4096_post_synth.v
select -assert-count 1 t:TDP36K

select -clear
design -load bram_sdp_split
select BRAM_SDP_SPLIT_2x2x8192
select *
synth_quicklogic -family qlf_k6n10f -top BRAM_SDP_SPLIT_2x2x8192
opt_expr -undriven
opt_clean
stat
write_verilog sim/bram_sdp_split_2x2x8192_post_synth.v
select -assert-count 1 t:TDP36K

select -clear
design -load bram_sdp_split
select BRAM_SDP_SPLIT_2x1x16384
select *
synth_quicklogic -family qlf_k6n10f -top BRAM_SDP_SPLIT_2x1x16384
opt_expr -undriven
opt_clean
stat
write_verilog sim/bram_sdp_split_2x1x16384_post_synth.v
select -assert-count 1 t:TDP36K

