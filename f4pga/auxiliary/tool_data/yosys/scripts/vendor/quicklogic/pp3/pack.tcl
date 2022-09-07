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

f4pga value shareDir

set techamp_dir ${f4pga_shareDir}/techmaps/pp3

proc max {a b} {
    if {$a > $b} {
        return $a
    } else {
        return $b
    }
}

proc min {a b} {
    if {$a < $b} {
        return $a
    } else {
        return $b
    }
}

# Returns the required number of C_FRAGs to fit the design
proc get_used_c_frag {} {
    set used_c_frag [get_count -cells t:mux8x0 t:LUT4 t:logic_cell_macro]
    set used_t_frag [get_count -cells t:mux4x0 t:LUT2 t:LUT3]

    set used_c_frag_for_t_frag [expr int(ceil($used_t_frag  / 2.0))]
    return [expr $used_c_frag + $used_c_frag_for_t_frag]
}

# Returns the required number of F_FRAGs to fit the design
proc get_used_f_frag {} {
    return [get_count -cells t:inv t:mux2x0 t:LUT1 t:logic_cell_macro]
}

# =============================================================================

proc pack {} {
    if { [f4pga is_dry] } {
        return
    }

    # Load the plugin that allows to retrieve cell count
    yosys plugin -i design_introspection
    yosys -import

    # Maximum number of LOGIC cells in the device
    set max_logic 891

    # Target number of LOGIC cells. This is less than max to allow the VPR
    # packet to have more freedom.
    set target_logic [expr int($max_logic * 0.90)]
    puts "PACK: Optimizing for target of $target_logic/$max_logic LOGIC cells"

    # LUT3 -> mux2x0 (replace)
    set used_c_frag [get_used_c_frag]
    if {$used_c_frag > $target_logic} {
        puts "PACK: Device overfitted $used_c_frag / $target_logic"

        # Update
        set required_frags [expr 2 * ($used_c_frag - $target_logic)]
        set used_f_frag [get_used_f_frag]
        set free_f_frag [expr $target_logic - $used_f_frag]

        # Try converting LUT3 to mux2x0
        if {$free_f_frag > 0} {
            puts "PACK: Replacing at most $free_f_frag LUT3 with mux2x0"

            set sel_count [min $required_frags $free_f_frag]
            yosys techmap -map ${techamp_dir}/lut3tomux2.v t:LUT3 %R$sel_count
        }
    }

    # LUT2 -> mux2x0 (replace)
    set used_c_frag [get_used_c_frag]
    if {$used_c_frag > $target_logic} {
        puts "PACK: Device overfitted $used_c_frag / $target_logic"

        # Update
        set required_frags [expr 2 * ($used_c_frag - $target_logic)]
        set used_f_frag [get_used_f_frag]
        set free_f_frag [expr $target_logic - $used_f_frag]

        # Try converting LUT2 to mux2x0
        if {$free_f_frag > 0} {
            puts "PACK: Replacing at most $free_f_frag LUT2 with mux2x0"

            set sel_count [min $required_frags $free_f_frag]
            yosys techmap -map ${techamp_dir}/lut2tomux2.v t:LUT2 %R$sel_count
        }
    }

    # Split mux4x0
    set used_c_frag [get_used_c_frag]
    if {$used_c_frag > $target_logic} {
        puts "PACK: Device overfitted $used_c_frag / $target_logic"

        # Update
        set required_frags [expr 2 * ($used_c_frag - $target_logic)]
        set used_f_frag [get_used_f_frag]
        set free_f_frag [expr $target_logic - $used_f_frag]

        # Try converting mux4x0 to 3x mux2x0
        if {$free_f_frag >= 3} {
            puts "PACK: Splitting at most $free_f_frag mux4x0 to 3x mux2x0"

            set sel_count [min $required_frags [expr int(floor($free_f_frag / 3.0))]]

            # If there are not enough mux4x0 then map some LUT2 to them (these are
            # actually equivalent)
            set mux4_count [get_count -cells t:mux4x0]
            if {$mux4_count < $sel_count} {
                set map_count [expr $sel_count - $mux4_count]
                puts "PACK: Replacing at most $map_count LUT2 with mux4x0"
                yosys techmap -map ${techamp_dir}/lut2tomux4.v t:LUT2 %R$map_count
            }

            yosys techmap -map ${techamp_dir}/mux4tomux2.v t:mux4x0 %R$sel_count
        }
    }

    # Split mux8x0
    set used_c_frag [get_used_c_frag]
    if {$used_c_frag > $target_logic} {
        puts "PACK: Device overfitted $used_c_frag / $target_logic"

        # Update
        set required_frags [expr 2 * ($used_c_frag - $target_logic)]
        set used_f_frag [get_used_f_frag]
        set free_f_frag [expr $target_logic - $used_f_frag]

        # Try converting mux8x0 to 7x mux2x0
        if {$free_f_frag >= 7} {
            puts "PACK: Splitting at most $free_f_frag mux8x0 to 7x mux2x0"

            set sel_count [min $required_frags [expr int(floor($free_f_frag / 7.0))]]
            yosys techmap -map ${techamp_dir}/mux8tomux2.v t:mux8x0 %R$sel_count
        }
    }

    # Final check
    set used_c_frag [get_used_c_frag]
    if {$used_c_frag > $target_logic} {
        puts "PACK: Device overfitted $used_c_frag / $target_logic. No more optimization possible!"
    }
}
