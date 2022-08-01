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

# Clean
opt_clean

f4pga take     synth_json
f4pga produce  eblif              [noext $f4pga_synth_json].eblif  -meta "Extended BLIF circuit description"

read_json ${f4pga_synth_json}

# Write EBLIF
write_blif -attr -cname -param \
    -true VCC VCC \
    -false GND GND \
    -undef VCC VCC \
    $f4pga_eblif
