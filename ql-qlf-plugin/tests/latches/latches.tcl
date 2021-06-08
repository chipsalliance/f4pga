yosys -import
if { [info procs synth_quicklogic] == {} } { plugin -i ql-qlf }
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

