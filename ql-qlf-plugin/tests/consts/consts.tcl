yosys -import
if { [info procs quicklogic_eqn] == {} } { plugin -i ql-qlf }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v

synth_quicklogic -top my_top -family pp3
stat
yosys cd my_top
select -assert-count 1 t:my_lut
select -assert-count 1 t:inpad
select -assert-count 1 t:outpad
select -assert-count 1 t:logic_0
select -assert-count 1 t:logic_1
