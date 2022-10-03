yosys -import
if { [info procs dsp_ff] == {} } { plugin -i dsp-ff }
yosys -import  ;# ingest plugin commands

set DSP_RULES [file dirname $::env(DESIGN_TOP)]/../../nexus-dsp_rules.txt

read_verilog $::env(DESIGN_TOP).v
design -save read

set TOP "conflict_out_fanout"
design -load read
hierarchy -top ${TOP}
synth_nexus -flatten
techmap -map +/nexus/cells_sim.v t:VLO t:VHI %u ;# Unmap VHI and VLO
debug dsp_ff -rules ${DSP_RULES}
stat
select -assert-count 1 t:MULT9X9
select -assert-count 18 t:FD1P3IX

set TOP "conflict_out_fanout_to_top"
design -load read
hierarchy -top ${TOP}
synth_nexus -flatten
techmap -map +/nexus/cells_sim.v t:VLO t:VHI %u ;# Unmap VHI and VLO
debug dsp_ff -rules ${DSP_RULES}
stat
select -assert-count 1 t:MULT9X9
select -assert-count 18 t:FD1P3IX

set TOP "conflict_inp_fanout"
design -load read
hierarchy -top ${TOP}
synth_nexus -flatten
techmap -map +/nexus/cells_sim.v t:VLO t:VHI %u ;# Unmap VHI and VLO
debug dsp_ff -rules ${DSP_RULES}
stat
select -assert-count 1 t:MULT9X9
select -assert-count 9 t:FD1P3IX

set TOP "conflict_inp_fanout_to_top"
design -load read
hierarchy -top ${TOP}
synth_nexus -flatten
techmap -map +/nexus/cells_sim.v t:VLO t:VHI %u ;# Unmap VHI and VLO
debug dsp_ff -rules ${DSP_RULES}
stat
select -assert-count 1 t:MULT9X9
select -assert-count 9 t:FD1P3IX
