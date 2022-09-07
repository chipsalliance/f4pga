# Copyright (C) 2022 F4PGA Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

yosys -import

#plugin -i ql-iob
#plugin -i ql-qlf

yosys -import

f4pga value     python3
f4pga value     pinmap
f4pga value     shareDir
f4pga value     yosys_plugins?
f4pga value     top
f4pga value     surelog_cmd?
f4pga take      build_dir
f4pga take      sources
f4pga take      pcf

f4pga produce   eblif            ${f4pga_build_dir}/${f4pga_top}.eblif      -meta "Extended BLIF circuit description"
# See comment about on-demands in the xc7 tcl script.
f4pga produce   synth_v_premap   ${f4pga_build_dir}/${f4pga_top}_premap.v  -meta "Structural verilog"
f4pga produce   json             ${f4pga_build_dir}/${f4pga_top}.json      -meta "Yosys JSON netlist"
f4pga tempfile  json_org
f4pga tempfile  json_presplit

log ">>> F4PGA Phase 1: Synthesis"

if { [contains $f4pga_yosys_plugins uhdm] } {
    foreach {sysverilog_source} $f4pga_sources {
        read_verilog_with_uhdm $surelog_cmd $sysverilog_source
    }    
} else {
    foreach {verilog_source} $f4pga_sources {
        read_verilog $verilog_source
    }    
}

# Read VPR cells library
read_verilog -lib -specify ${f4pga_shareDir}/techmaps/pp3/cells_sim.v
# Read device specific cells library
read_verilog -lib -specify ${f4pga_shareDir}/arch/ql-eos-s3_wlcsp/cells/ram_sim.v

# Synthesize
synth_quicklogic -family pp3

# Optimize the netlist by adaptively splitting cells that fit into C_FRAG into
# smaller that can fit into F_FRAG.
set mypath [ file dirname [ file normalize [ info script ] ] ]
source "$mypath/pack.tcl"

pack
stat

# Assing parameters to IO cells basing on constraints and package pinmap
if { $f4pga_pcf != "" && $f4pga_pinmap != ""} {
    quicklogic_iob $f4pga_pcf $f4pga_pinmap
}

# Write a pre-mapped design
write_verilog $f4pga_synth_v_premap

# Select all logic_0 and logic_1 and apply the techmap to them first. This is
# necessary for constant connection detection in the subsequent techmaps.
select -set consts t:logic_0 t:logic_1
techmap -map ${f4pga_shareDir}/techmaps/pp3/cells_map.v @consts

# Map to the VPR cell library
techmap -map ${f4pga_shareDir}/techmaps/pp3/cells_map.v
# Map to the device specific VPR cell library
techmap -map ${f4pga_shareDir}/arch/ql-eos-s3_wlcsp/cells/ram_map.v

# opt_expr -undriven makes sure all nets are driven, if only by the $undef
# net.
opt_expr -undriven
opt_clean
setundef -zero -params
stat

log ">>> F4PGA Phase 2: Cell names fixup"

# Write output JSON, fixup cell names using an external Python script
write_json $f4pga_json_org
exec $f4pga_python3 ${f4pga_shareDir}/scripts/yosys_fixup_cell_names.py $f4pga_json_org $f4pga_json_presplit

log ">>> F4PGA Phase 3: Splitting in/outs"

exec ${f4pga_python3} ${f4pga_shareDir}/scripts/split_inouts.py -i $f4pga_json_presplit -o $f4pga_json


log ">>> F4PGA Phase 4: Writing eblif"
design -reset

read_json ${f4pga_json}

write_blif -attr -cname -param \
    -true VCC VCC \
    -false GND GND \
    -undef VCC VCC \
    $f4pga_eblif