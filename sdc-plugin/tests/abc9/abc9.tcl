yosys -import
if { [info procs read_sdc] == {} } { plugin -i sdc }
yosys -import  ;# ingest plugin commands

# ensure abc9.D is unset
scratchpad -assert-unset abc9.D

read_verilog abc9.v
read_sdc abc9.sdc

# check that abc9.D was set to half the fastest clock period in the design
scratchpad -assert abc9.D 5000
