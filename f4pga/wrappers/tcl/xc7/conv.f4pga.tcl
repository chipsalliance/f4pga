yosys -import

# Clean
opt_clean

# Designs that directly tie OPAD's to constants cannot use the dedicate
# constant network as an artifact of the way the ROI is configured.
# Until the ROI is removed, enable designs to selectively disable the dedicated
# constant network.
if { [info exists ::env(USE_LUT_CONSTANTS)] } {
    write_blif -attr -cname -param \
      $::env(OUT_EBLIF)
} else {
    write_blif -attr -cname -param \
      -true VCC VCC \
      -false GND GND \
      -undef VCC VCC \
    $::env(OUT_EBLIF)
}

