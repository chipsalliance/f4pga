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

plugin -i fasm

# Import the commands from the plugins to the tcl interpreter
yosys -import

f4pga value    top
f4pga value    part_name
f4pga value    yosys_plugins?
f4pga take     sources
f4pga take     build_dir
f4pga produce  json            ${f4pga_build_dir}/${f4pga_top}.json      -meta "Yosys JSON netlist"
f4pga produce  synth_v         ${f4pga_build_dir}/${f4pga_top}_premap.v  -meta "Pre-technology mapped structural verilog"

if { [contains $f4pga_yosys_plugins uhdm] } {
    foreach {sysverilog_source} $f4pga_sources {
        read_verilog_with_uhdm $surelog_cmd $sysverilog_source
    }    
} else {
    foreach {verilog_source} $f4pga_sources {
        read_verilog $verilog_source
    }    
}

synth_ice40 -nocarry

opt_expr -undriven
opt_clean

attrmap -remove hdlname

setundef -zero -params
write_json $f4pga_json
write_verilog $f4pga_synth_v
