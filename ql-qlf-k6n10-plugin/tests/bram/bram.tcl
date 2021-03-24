yosys -import
if { [info procs synth_quicklogic] == {} } { plugin -i ql-qlf-k6n10 }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
hierarchy -top BRAM_32x512
yosys proc
yosys memory
equiv_opt -assert -map +/quicklogic/qlf_k6n10_cells_sim.v synth_quicklogic -top BRAM_32x512

design -load read
synth_quicklogic -top BRAM_16x1024
yosys cd BRAM_16x1024
stat
select -assert-count 1 t:DP_RAM16K

design -load read
synth_quicklogic -top BRAM_8x2048
yosys cd BRAM_16x1024
stat
select -assert-count 1 t:DP_RAM16K

design -load read
synth_quicklogic -top BRAM_4x4096
yosys cd BRAM_16x1024
stat
select -assert-count 1 t:DP_RAM16K
