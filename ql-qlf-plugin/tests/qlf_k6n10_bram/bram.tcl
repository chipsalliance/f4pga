yosys -import
if { [info procs quicklogic_eqn] == {} } { plugin -i ql-qlf }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
hierarchy -top BRAM_32x512
yosys proc
yosys memory
equiv_opt -assert -map +/quicklogic/qlf_k6n10_cells_sim.v synth_quicklogic -family qlf_k6n10 -top BRAM_32x512

design -load read
synth_quicklogic -family qlf_k6n10 -top BRAM_16x1024
yosys cd BRAM_16x1024
stat
select -assert-count 1 t:DP_RAM16K

design -load read
synth_quicklogic -family qlf_k6n10 -top BRAM_8x2048
yosys cd BRAM_16x1024
stat
select -assert-count 1 t:DP_RAM16K

design -load read
synth_quicklogic -family qlf_k6n10 -top BRAM_4x4096
yosys cd BRAM_16x1024
stat
select -assert-count 1 t:DP_RAM16K
