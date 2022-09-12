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

proc noext { varref } {
    # Extension is striped by the f4pga python tool. This code just modifies
    # variable refernces to inform f4pga that it should strip the extension.
    regsub -all {\${([A-Za-z_:]*)}} $varref {${\1[noext]}} varref_noext
    return $varref_noext
}

proc contains { l e } {
    foreach entry [split l " "] {
        if { $entry == $e } {
            return true
        }
    }
    return false
}
