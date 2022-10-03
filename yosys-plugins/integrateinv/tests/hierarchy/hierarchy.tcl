yosys -import
if { [info procs integrateinv] == {} } { plugin -i integrateinv }
yosys -import  ;# ingest plugin commands

read_verilog -icells $::env(DESIGN_TOP).v
hierarchy -check -auto-top

debug integrateinv

select -module top
select t:\$_NOT_ -assert-count 1
select t:box r:INV_A=1'b1 %i -assert-count 1
select t:child -assert-count 1

select -module child
select t:\$_NOT_ -assert-count 0
select t:box r:INV_A=1'b1 %i -assert-count 1
