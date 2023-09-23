yosys -import
if { [info procs quicklogic_eqn] == {} } { plugin -i ql-qlf }
yosys -import  ;# ingest plugin commands

#Logic test for qlf_k4n8 device
read_verilog $::env(DESIGN_TOP).v
hierarchy -top top
yosys proc
equiv_opt -assert -map +/quicklogic/qlf_k4n8/cells_sim.v synth_quicklogic -family qlf_k4n8
design -load postopt
yosys cd top

stat
select -assert-count 9 t:\$lut

design -reset

#Logic test for qlf_k6n10 device
read_verilog $::env(DESIGN_TOP).v
hierarchy -top top
yosys proc
equiv_opt -assert -map +/quicklogic/qlf_k6n10/cells_sim.v synth_quicklogic -family qlf_k6n10
design -load postopt
yosys cd top

stat
select -assert-count 9 t:\$lut

design -reset

#Logic test for pp3 device
read_verilog $::env(DESIGN_TOP).v
hierarchy -top top
yosys proc
equiv_opt -assert -map +/quicklogic/pp3/cells_sim.v synth_quicklogic -family pp3
design -load postopt
yosys cd top

stat
select -assert-count 1 t:LUT1
select -assert-count 6 t:LUT2
select -assert-count 2 t:LUT3
select -assert-count 8 t:inpad
select -assert-count 10 t:outpad

select -assert-none t:LUT1 t:LUT2 t:LUT3 t:inpad t:outpad %% t:* %D
