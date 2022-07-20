yosys -import

synth_ice40 -nocarry

opt_expr -undriven
opt_clean

attrmap -remove hdlname
setundef -zero -params

write_json $::env(OUT_JSON)
#write_verilog $::env(OUT_SYNTH_V)
