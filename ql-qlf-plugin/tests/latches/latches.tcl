yosys -import
if { [info procs quicklogic_eqn] == {} } { plugin -i ql-qlf }
yosys -import  ;# ingest plugin commands

read_verilog $::env(DESIGN_TOP).v
design -save read

# Tests for qlf_k6n10 family
# LATCHP
design -load read
synth_quicklogic -family qlf_k6n10 -top latchp
yosys cd latchp
stat
select -assert-count 1 t:latchsre

# LATCHN
design -load read
synth_quicklogic -family qlf_k6n10 -top latchn
yosys cd latchn
stat
select -assert-count 1 t:\$lut
select -assert-count 1 t:latchsre

# LATCHSRE
design -load read
synth_quicklogic -family qlf_k6n10 -top my_latchsre
yosys cd my_latchsre
stat
select -assert-count 2 t:\$lut
select -assert-count 1 t:latchsre

## Tests for qlf_k4n8 family
## Currently disabled cause latch aren't supported
## in synth_quicklogic for that family
## LATCHP
#synth_quicklogic -family qlf_k4n8 -top latchp
#yosys cd latchp
#stat
#select -assert-count 1 t:\$_DLATCH_P_
#
## LATCHP no init
#design -load read
#synth_quicklogic -family qlf_k4n8 -top latchp_noinit
#yosys cd latchp_noinit
#stat
#select -assert-count 1 t:\$_DLATCH_P_

# Latches for PP3

# LATCHP
design -load read
hierarchy -top latchp_noinit
yosys proc
# Can't run any sort of equivalence check because latches are blown to LUTs
synth_quicklogic -family pp3 -top latchp_noinit
yosys cd latchp_noinit
select -assert-count 1 t:LUT3
select -assert-count 3 t:inpad
select -assert-count 1 t:outpad

select -assert-none t:LUT3 t:inpad t:outpad %% t:* %D

# LATCHN
design -load read
hierarchy -top latchn
yosys proc
# Can't run any sort of equivalence check because latches are blown to LUTs
synth_quicklogic -family pp3 -top latchn
yosys cd latchn
select -assert-count 1 t:LUT3
select -assert-count 3 t:inpad
select -assert-count 1 t:outpad

select -assert-none t:LUT3 t:inpad t:outpad %% t:* %D

# LATCHSRE
design -load read
hierarchy -top my_latchsre
yosys proc
# Can't run any sort of equivalence check because latches are blown to LUTs
synth_quicklogic -family pp3 -top my_latchsre
yosys cd my_latchsre
select -assert-count 1 t:LUT2
select -assert-count 1 t:LUT4
select -assert-count 5 t:inpad
select -assert-count 1 t:outpad

select -assert-none t:LUT2 t:LUT4 t:inpad t:outpad %% t:* %D

