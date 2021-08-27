yosys -import
if { [info procs quicklogic_eqn] == {} } { plugin -i ql-qlf }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
design -save read

hierarchy -top fsm
yosys proc
flatten

equiv_opt -run :prove -map +/quicklogic/pp3/cells_sim.v synth_quicklogic -family pp3
async2sync
miter -equiv -make_assert -flatten gold gate miter
sat -verify -prove-asserts -show-public -set-at 1 in_reset 1 -seq 20 -prove-skip 1 miter

design -load postopt
yosys cd fsm

select -assert-count 1 t:LUT2
select -assert-count 9 t:LUT3
select -assert-count 4 t:dffepc
select -assert-count 1 t:logic_0
select -assert-count 1 t:logic_1
select -assert-count 3 t:inpad
select -assert-count 2 t:outpad
select -assert-count 1 t:ckpad

select -assert-none t:LUT2 t:LUT3 t:dffepc t:logic_0 t:logic_1 t:inpad t:outpad t:ckpad %% t:* %D

