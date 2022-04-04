yosys -import
if { [info procs quicklogic_eqn] == {} } { plugin -i ql-qlf }
yosys -import  ;# ingest plugin commands

# Equivalence check for adder synthesis for qlf-k4n8
read_verilog -icells -DWIDTH=4 $::env(DESIGN_TOP).v
hierarchy -check -top full_adder
yosys proc
equiv_opt -assert -map +/quicklogic/qlf_k4n8/cells_sim.v synth_quicklogic -family qlf_k4n8

design -reset

# Equivalence check for subtractor synthesis
read_verilog -icells -DWIDTH=4 $::env(DESIGN_TOP).v
hierarchy -check -top subtractor
yosys proc
equiv_opt -assert  -map +/quicklogic/qlf_k4n8/cells_sim.v synth_quicklogic -family qlf_k4n8
design -reset

# Equivalence check for comparator synthesis
read_verilog -icells -DWIDTH=4 $::env(DESIGN_TOP).v
hierarchy -check -top comparator
yosys proc
equiv_opt -assert  -map +/quicklogic/qlf_k4n8/cells_sim.v synth_quicklogic -family qlf_k4n8
design -reset

# Equivalence check for adder synthesis for qlf-k6n10
read_verilog -icells -DWIDTH=4 $::env(DESIGN_TOP).v
hierarchy -check -top full_adder
yosys proc
equiv_opt -assert  -map +/quicklogic/qlf_k6n10/cells_sim.v synth_quicklogic -family qlf_k6n10
design -load postopt
yosys cd full_adder
stat
select -assert-count 6 t:adder

design -reset

# Equivalence check for subtractor synthesis for qlf-k6n10
read_verilog -icells -DWIDTH=4 $::env(DESIGN_TOP).v
hierarchy -check -top subtractor
yosys proc
equiv_opt -assert  -map +/quicklogic/qlf_k6n10/cells_sim.v synth_quicklogic -family qlf_k6n10
design -load postopt
yosys cd subtractor
stat
select -assert-count 6 t:adder

design -reset

# Equivalence check for comparator synthesis for qlf-k6n10
read_verilog -icells -DWIDTH=4 $::env(DESIGN_TOP).v
hierarchy -check -top comparator
yosys proc
equiv_opt -assert  -map +/quicklogic/qlf_k6n10/cells_sim.v synth_quicklogic -family qlf_k6n10
design -load postopt
yosys cd comparator
stat
select -assert-count 5 t:adder

design -reset

# Equivalence check for adder synthesis for qlf-k6n10
read_verilog -icells -DWIDTH=4 $::env(DESIGN_TOP).v
hierarchy -check -top full_adder
yosys proc
equiv_opt -assert  -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f
design -load postopt
yosys cd full_adder
stat
select -assert-count 5 t:adder_carry

design -reset

# Equivalence check for subtractor synthesis for qlf-k6n10
read_verilog -icells -DWIDTH=4 $::env(DESIGN_TOP).v
hierarchy -check -top subtractor
yosys proc
equiv_opt -assert  -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f
design -load postopt
yosys cd subtractor
stat
select -assert-count 5 t:adder_carry

design -reset

# Equivalence check for comparator synthesis for qlf-k6n10
read_verilog -icells -DWIDTH=4 $::env(DESIGN_TOP).v
hierarchy -check -top comparator
yosys proc
equiv_opt -assert  -map +/quicklogic/qlf_k6n10f/cells_sim.v synth_quicklogic -family qlf_k6n10f
design -load postopt
yosys cd comparator
stat
select -assert-count 4 t:adder_carry

design -reset

# Equivalence check for adder synthesis for pp3
read_verilog -icells -DWIDTH=4 $::env(DESIGN_TOP).v
hierarchy -check -top full_adder
yosys proc
equiv_opt -assert -map +/quicklogic/pp3/cells_sim.v synth_quicklogic -family pp3
design -load postopt
yosys cd full_adder

stat
select -assert-count 2 t:LUT2
select -assert-count 6 t:LUT3
select -assert-count 8 t:inpad
select -assert-count 5 t:outpad

select -assert-none t:LUT2 t:LUT3 t:inpad t:outpad %% t:* %D


design -reset

# Equivalence check for subtractor synthesis for pp3
read_verilog -icells -DWIDTH=4 $::env(DESIGN_TOP).v
hierarchy -check -top subtractor
yosys proc
equiv_opt -assert -map +/quicklogic/pp3/cells_sim.v synth_quicklogic -family pp3
design -load postopt
yosys cd subtractor

stat
select -assert-count 2 t:LUT2
select -assert-count 6 t:LUT3
select -assert-count 8 t:inpad
select -assert-count 5 t:outpad

select -assert-none t:LUT2 t:LUT3 t:inpad t:outpad %% t:* %D

design -reset

# Equivalence check for comparator synthesis for pp3
read_verilog -icells -DWIDTH=4 $::env(DESIGN_TOP).v
hierarchy -check -top comparator
yosys proc
equiv_opt -assert -map +/quicklogic/pp3/cells_sim.v synth_quicklogic -family pp3
design -load postopt
yosys cd comparator

stat

# Types and counts of LUTs inferred seem to differ depending on the way Yosys
# is built. In any case the equivalence check passes. Disabling cell count
# assertions for now.
# I've opened an issue https://github.com/SymbiFlow/yosys-f4pga-plugins/issues/284

#select -assert-count 3 t:LUT2
#select -assert-count 2 t:LUT4
#select -assert-count 8 t:inpad
#select -assert-count 1 t:outpad
#select -assert-none t:LUT2 t:LUT4 t:inpad t:outpad %% t:* %D
