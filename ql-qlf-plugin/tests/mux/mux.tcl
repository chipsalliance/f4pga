yosys -import
if { [info procs quicklogic_eqn] == {} } { plugin -i ql-qlf }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
design -save read

hierarchy -top mux2
yosys proc
equiv_opt -assert -map +/quicklogic/pp3/cells_sim.v synth_quicklogic -family pp3
design -load postopt
yosys cd mux2
select -assert-count 1 t:LUT3
select -assert-count 3 t:inpad
select -assert-count 1 t:outpad

select -assert-none t:LUT3 t:inpad t:outpad %% t:* %D

design -load read
hierarchy -top mux4
yosys proc
equiv_opt -assert -map +/quicklogic/pp3/cells_sim.v synth_quicklogic -family pp3
design -load postopt
yosys cd mux4
select -assert-count 3 t:LUT3
select -assert-count 6 t:inpad
select -assert-count 1 t:outpad

select -assert-none t:LUT3 t:inpad t:outpad %% t:* %D

design -load read
hierarchy -top mux8
yosys proc
equiv_opt -assert -map +/quicklogic/pp3/cells_sim.v synth_quicklogic -family pp3
design -load postopt
yosys cd mux8
select -assert-count 1 t:LUT1
select -assert-count 1 t:LUT3
select -assert-count 2 t:mux4x0
select -assert-count 11 t:inpad
select -assert-count 1 t:outpad

select -assert-none t:LUT1 t:LUT3 t:mux4x0 t:inpad t:outpad %% t:* %D

design -load read
hierarchy -top mux16
yosys proc
equiv_opt -assert -map +/quicklogic/pp3/cells_sim.v synth_quicklogic -family pp3
design -load postopt
yosys cd mux16
select -assert-count 1 t:LUT3
select -assert-count 2 t:mux8x0
select -assert-count 20 t:inpad
select -assert-count 1 t:outpad

select -assert-none t:LUT3 t:mux8x0 t:inpad t:outpad %% t:* %D
