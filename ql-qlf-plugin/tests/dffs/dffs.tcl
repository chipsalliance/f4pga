yosys -import
if { [info procs synth_quicklogic] == {} } { plugin -i ql-qlf }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
design -save read

# DFF
hierarchy -top my_dff
yosys proc
equiv_opt -assert -map +/quicklogic/qlf_k4n8_cells_sim.v synth_quicklogic -family qlf_k4n8 -top my_dff
design -load postopt
yosys cd my_dff
stat
select -assert-count 1 t:dff

# DFFR (posedge RST)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffr_p
yosys cd my_dffr_p
stat
select -assert-count 1 t:dffr
select -assert-count 1 t:\$lut

# DFFR (negedge RST)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffr_n
yosys cd my_dffr_n
stat
select -assert-count 1 t:dffr

# DFFS (posedge SET)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffs_p
yosys cd my_dffs_p
stat
select -assert-count 1 t:dffs
select -assert-count 1 t:\$lut

# DFFS (negedge SET)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffs_n
yosys cd my_dffs_n
stat
select -assert-count 1 t:dffs

# DFFN
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffn
yosys cd my_dffn
stat
select -assert-count 1 t:dffn


# DFFNR (negedge CLK posedge RST)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffnr_p
yosys cd my_dffnr_p
stat
select -assert-count 1 t:dffnr
select -assert-count 1 t:\$lut

# DFFNR (negedge CLK negedge RST)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffnr_n
yosys cd my_dffnr_n
stat
select -assert-count 1 t:dffnr

# DFFNS (negedge CLK posedge SET)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffns_p
yosys cd my_dffns_p
stat
select -assert-count 1 t:dffns
select -assert-count 1 t:\$lut

# DFFS (negedge CLK negedge SET)
design -load read
synth_quicklogic -family qlf_k4n8 -top my_dffns_n
yosys cd my_dffns_n
stat
select -assert-count 1 t:dffns

design -reset

# DFF on qlf_k6n10 device
read_verilog $::env(DESIGN_TOP).v
# DFF
hierarchy -top my_dff
yosys proc
equiv_opt -assert -map +/quicklogic/qlf_k4n8_cells_sim.v synth_quicklogic -family qlf_k6n10 -top my_dff
design -load postopt
yosys cd my_dff
stat
select -assert-count 1 t:dff
