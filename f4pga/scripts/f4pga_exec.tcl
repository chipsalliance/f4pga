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

proc f4pga {action name args} {
    regsub {(.*)[!?]} $name {\1} name_dec
    upvar f4pga_${name_dec} f4pgavar

    if { $action eq "take" || $action eq "produce" } {
        set f4pgavar $::env(DEP_${name_dec})
    } elseif { $action eq "value" } {
        set f4pgavar $::env(VAL_${name_dec})
    } elseif { $action eq "tempfile" } {
        set f4pgavar $::env(TMP_${name_dec})
    } else {
        error "Unsupported f4pga subcommand `${action}`" 99
    }

    return $f4pgavar
}
