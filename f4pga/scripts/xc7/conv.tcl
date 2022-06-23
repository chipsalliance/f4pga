# Copyright (C) 2019-2022 F4PGA Authors
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

# Clean
opt_clean

source [file join [file normalize [info script]] .. utils.tcl]

f4pga take     synth_json
f4pga value    use_lut_constants
f4pga produce  eblif              [noext $f4pga_synth_json].eblif  -meta "Extended BLIF circuit description"

read_json ${f4pga_synth_json}

# Designs that directly tie OPAD's to constants cannot use the dedicate
# constant network as an artifact of the way the ROI is configured.
# Until the ROI is removed, enable designs to selectively disable the dedicated
# constant network.
if { $f4pga_use_lut_constants == "TRUE" } {
    write_blif -attr -cname -param $f4pga_eblif
} else {
    write_blif -attr -cname -param \
      -true VCC VCC \
      -false GND GND \
      -undef VCC VCC \
    $f4pga_eblif
}
