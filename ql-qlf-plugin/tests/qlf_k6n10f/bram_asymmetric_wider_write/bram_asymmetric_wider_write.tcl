yosys -import

if { [info procs ql-qlf-k6n10f] == {} } { plugin -i ql-qlf }
yosys -import  ;

read_verilog $::env(DESIGN_TOP).v
design -save bram_tdp

select spram_16x1024_8x2048
select *
synth_quicklogic -family qlf_k6n10f -top spram_16x1024_8x2048
opt_expr -undriven
opt_clean
stat
write_verilog sim/spram_16x1024_8x2048_post_synth.v
select -assert-count 1 t:TDP36K

select -clear
design -load bram_tdp
select spram_16x2048_8x4096
select *
synth_quicklogic -family qlf_k6n10f -top spram_16x2048_8x4096
opt_expr -undriven
opt_clean
stat
write_verilog sim/spram_16x2048_8x4096_post_synth.v
select -assert-count 1 t:TDP36K

select -clear
design -load bram_tdp
select spram_32x1024_16x2048
select *
synth_quicklogic -family qlf_k6n10f -top spram_32x1024_16x2048
opt_expr -undriven
opt_clean
stat
write_verilog sim/spram_32x1024_16x2048_post_synth.v
select -assert-count 1 t:TDP36K

select -clear
design -load bram_tdp
select spram_32x1024_8x4096
select *
synth_quicklogic -family qlf_k6n10f -top spram_32x1024_8x4096
opt_expr -undriven
opt_clean
stat
write_verilog sim/spram_32x1024_8x4096_post_synth.v
select -assert-count 1 t:TDP36K


