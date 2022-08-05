yosys -import

# Clean
opt_clean

# Write EBLIF
write_blif -attr -cname -param $::env(OUT_EBLIF)
