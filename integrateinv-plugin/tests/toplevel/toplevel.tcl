yosys -import
plugin -i integrateinv

read_verilog -icells $::env(DESIGN_TOP).v
hierarchy -check -auto-top

debug integrateinv

select t:\$_NOT_ -assert-count 1
