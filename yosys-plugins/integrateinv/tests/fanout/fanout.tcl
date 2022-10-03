yosys -import
if { [info procs integrateinv] == {} } { plugin -i integrateinv }
yosys -import  ;# ingest plugin commands

read_verilog -icells $::env(DESIGN_TOP).v
hierarchy -check -auto-top

debug integrateinv

select t:\$_NOT_ -assert-count 1
select t:box r:INV_A=1'b1 %i -assert-count 3
