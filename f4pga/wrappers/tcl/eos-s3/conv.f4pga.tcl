yosys -import

# Clean
opt_clean

# Write EBLIF
write_blif -attr -cname -param \
    -true VCC VCC \
    -false GND GND \
    -undef VCC VCC \
    $::env(OUT_EBLIF)
