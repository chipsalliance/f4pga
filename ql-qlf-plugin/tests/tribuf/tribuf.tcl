yosys -import
if { [info procs quicklogic_eqn] == {} } { plugin -i ql-qlf }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v

hierarchy -top tristate
yosys proc
tribuf
flatten
synth
equiv_opt -assert -map +/quicklogic/pp3/cells_sim.v -map +/simcells.v synth_quicklogic -family pp3
design -load postopt
yosys cd tristate
select -assert-count 2 t:inpad
select -assert-count 1 t:outpad
select -assert-count 1 t:\$_TBUF_
select -assert-none t:inpad t:outpad t:\$_TBUF_ %% t:* %D

