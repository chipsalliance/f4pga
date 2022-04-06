yosys -import
if { [info procs dsp_ff] == {} } { plugin -i dsp-ff }
yosys -import  ;# ingest plugin commands

set DSP_RULES [file dirname $::env(DESIGN_TOP)]/../../nexus-dsp_rules.txt

read_verilog $::env(DESIGN_TOP).v
design -save read

set TOP "mult_wide"
design -load read
hierarchy -top ${TOP}
synth_nexus -flatten
techmap -map +/nexus/cells_sim.v t:VLO t:VHI %u ;# Unmap VHI and VLO
equiv_opt -assert -async2sync -map +/nexus/cells_sim.v debug dsp_ff -rules ${DSP_RULES}
design -load postopt
yosys cd ${TOP}
stat
select -assert-count 1 t:MULTADDSUB9X9WIDE
select -assert-count 9 t:FD1P3IX
