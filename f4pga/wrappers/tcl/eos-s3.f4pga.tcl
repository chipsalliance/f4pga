yosys -import

plugin -i ql-iob
plugin -i ql-qlf

yosys -import

# Read VPR cells library
read_verilog -lib -specify $::env(TECHMAP_PATH)/cells_sim.v
# Read device specific cells library
read_verilog -lib -specify $::env(DEVICE_CELLS_SIM)

# Synthesize
synth_quicklogic -family pp3

# Optimize the netlist by adaptively splitting cells that fit into C_FRAG into
# smaller that can fit into F_FRAG.

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
        yosys techmap -map $::env(TECHMAP_PATH)/lut3tomux2.v t:LUT3 %R$sel_count
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
        yosys techmap -map $::env(TECHMAP_PATH)/lut2tomux2.v t:LUT2 %R$sel_count
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
            yosys techmap -map $::env(TECHMAP_PATH)/lut2tomux4.v t:LUT2 %R$map_count
        }

        yosys techmap -map $::env(TECHMAP_PATH)/mux4tomux2.v t:mux4x0 %R$sel_count
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
        yosys techmap -map $::env(TECHMAP_PATH)/mux8tomux2.v t:mux8x0 %R$sel_count
    }
}

# Final check
set used_c_frag [get_used_c_frag]
if {$used_c_frag > $target_logic} {
    puts "PACK: Device overfitted $used_c_frag / $target_logic. No more optimization possible!"
}

stat

# Assing parameters to IO cells basing on constraints and package pinmap
if { $::env(PCF_FILE) != "" && $::env(PINMAP_FILE) != ""} {
    quicklogic_iob $::env(PCF_FILE) $::env(PINMAP_FILE)
}

# Write a pre-mapped design
write_verilog $::env(OUT_SYNTH_V).premap.v

# Select all logic_0 and logic_1 and apply the techmap to them first. This is
# necessary for constant connection detection in the subsequent techmaps.
select -set consts t:logic_0 t:logic_1
techmap -map  $::env(TECHMAP_PATH)/cells_map.v @consts

# Map to the VPR cell library
techmap -map  $::env(TECHMAP_PATH)/cells_map.v
# Map to the device specific VPR cell library
techmap -map  $::env(DEVICE_CELLS_MAP)

# opt_expr -undriven makes sure all nets are driven, if only by the $undef
# net.
opt_expr -undriven
opt_clean
setundef -zero -params
stat

# Write output JSON, fixup cell names using an external Python script
write_json $::env(OUT_JSON).org.json
exec f4pga utils yosys_fixup_cell_names $::env(OUT_JSON).org.json $::env(OUT_JSON)

# Read the fixed JSON back and write verilog
design -reset
read_json $::env(OUT_JSON)
write_verilog $::env(OUT_SYNTH_V)

design -reset
exec $::env(PYTHON3) -m f4pga.aux.utils.yosys_split_inouts -i $::env(OUT_JSON) -o $::env(SYNTH_JSON)
read_json $::env(SYNTH_JSON)
yosys -import
opt_clean
write_blif -attr -cname -param \
  -true VCC VCC \
  -false GND GND \
  -undef VCC VCC \
  $::env(OUT_EBLIF)
