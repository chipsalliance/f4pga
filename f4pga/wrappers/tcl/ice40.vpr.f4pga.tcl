yosys -import

proc clean_processes {} {
    proc_clean
    proc_rmdead
    proc_prune
    proc_init
    proc_arst
    proc_mux
    proc_dlatch
    proc_dff
    proc_memwr
    proc_clean
}

synth_ice40 -nocarry

# opt_expr -undriven makes sure all nets are driven, if only by the $undef
# net.
opt_expr -undriven
opt_clean

# TODO: remove this as soon as new VTR master+wip is pushed: https://github.com/SymbiFlow/vtr-verilog-to-routing/pull/525
attrmap -remove hdlname

setundef -zero -params
clean_processes
write_json $::env(OUT_JSON)
write_verilog $::env(OUT_SYNTH_V)

design -reset
exec $::env(PYTHON3) -m f4pga.aux.utils.yosys_split_inouts -i $::env(OUT_JSON) -o $::env(SYNTH_JSON)
read_json $::env(SYNTH_JSON)
yosys -import
opt_clean
write_blif -attr -cname -param $::env(OUT_EBLIF)
