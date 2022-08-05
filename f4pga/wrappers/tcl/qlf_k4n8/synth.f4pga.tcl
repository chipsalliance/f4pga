yosys -import

# Load the QuickLogic qlf_k4n8 support plugin. Note that this is only temporary
# until support for the device is merged into the upstream Yosys
plugin -i ql-qlf
yosys -import

# Read VPR cells library
read_verilog -lib $::env(TECHMAP_PATH)/cells_sim.v

# Synthesize
if {[info exists ::env(SYNTH_OPTS)]} {
    synth_quicklogic -family qlf_k4n8 $::env(SYNTH_OPTS)
} else {
    synth_quicklogic -family qlf_k4n8
}

# Write a pre-mapped design
write_verilog $::env(OUT_SYNTH_V).premap.v

# Map to the VPR cell library
techmap -map  $::env(TECHMAP_PATH)/cells_map.v

# opt_expr -undriven makes sure all nets are driven, if only by the $undef
# net.
opt_expr -undriven
opt_clean

stat

write_json $::env(OUT_JSON)
write_verilog $::env(OUT_SYNTH_V)
