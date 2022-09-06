yosys -import

plugin -i xdc
plugin -i fasm
plugin -i params
plugin -i sdc
plugin -i design_introspection


# Import the commands from the plugins to the tcl interpreter
yosys -import


# Update the CLKOUT[0-5]_PHASE and CLKOUT[0-5]_DUTY_CYCLE parameter values.
# Due to the fact that Yosys doesn't support floating parameter values
# i.e. treats them as strings, the parameter values need to be multiplied by 1000
# for the PLL registers to have correct values calculated during techmapping.
proc multiply_param { cell param_name multiplier } {
    set param_value [getparam $param_name $cell]
    if {$param_value ne ""} {
        set new_param_value [expr int(round([expr $param_value * $multiplier]))]
        setparam -set $param_name $new_param_value $cell
        puts "Updated parameter $param_name of cell $cell from $param_value to $new_param_value"
    }
}

proc update_pll_and_mmcm_params {} {
    foreach cell [selection_to_tcl_list "t:PLLE2_ADV"] {
        multiply_param $cell "CLKFBOUT_PHASE" 1000
        for {set output 0} {$output < 6} {incr output} {
            multiply_param $cell "CLKOUT${output}_PHASE" 1000
            multiply_param $cell "CLKOUT${output}_DUTY_CYCLE" 100000
        }
    }

    foreach cell [selection_to_tcl_list "t:MMCME2_ADV"] {
        multiply_param $cell "CLKFBOUT_PHASE" 1000
        for {set output 0} {$output < 7} {incr output} {
            multiply_param $cell "CLKOUT${output}_PHASE" 1000
            multiply_param $cell "CLKOUT${output}_DUTY_CYCLE" 100000
        }
        multiply_param $cell "CLKFBOUT_MULT_F" 1000
        multiply_param $cell "CLKOUT0_DIVIDE_F" 1000
    }
}

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


# -flatten is used to ensure that the output eblif has only one module.
# Some of symbiflow expects eblifs with only one module.
#
# To solve the carry chain congestion at the output, the synthesis step
# needs to be executed two times.
# abc9 seems to cause troubles if called multiple times in the flow, therefore
# it gets called only at the last synthesis step
#
# Do not infer IOBs for targets that use a ROI.
if { $::env(USE_ROI) == "TRUE" } {
    synth_xilinx -flatten -nosrl -noclkbuf -nodsp -noiopad -nowidelut
} else {
    # Read Yosys baseline library first.
    read_verilog -lib -specify +/xilinx/cells_sim.v
    read_verilog -lib +/xilinx/cells_xtra.v

    # Overwrite some models (e.g. IBUF with more parameters)
    read_verilog -lib $::env(TECHMAP_PATH)/iobs.v

    # TODO: This should eventually end up in upstream Yosys
    #       as models such as FD are not currently supported
    #       as being used in old FPGAs (e.g. Spartan6)
    # Read in unsupported models
    read_verilog -lib $::env(TECHMAP_PATH)/retarget.v

    if { [info exists ::env(TOP)] && $::env(TOP) != "" } {
        hierarchy -check -top $::env(TOP)
    } else {
        hierarchy -check -auto-top
    }

    # Start flow after library reading
    synth_xilinx -flatten -nosrl -noclkbuf -nodsp -iopad -nowidelut -run prepare:check
}

# Check that post-synthesis cells match libraries.
hierarchy -check

if { [info exists ::env(INPUT_XDC_FILES)] && $::env(INPUT_XDC_FILES) != "" } {
  read_xdc -part_json $::env(PART_JSON) {*}$::env(INPUT_XDC_FILES)
  write_fasm -part_json $::env(PART_JSON)  $::env(OUT_FASM_EXTRA)

  # Perform clock propagation based on the information from the XDC commands
  propagate_clocks
}

update_pll_and_mmcm_params

# Write the SDC file
#
# Note that write_sdc and the SDC plugin holds live pointers to RTLIL objects.
# If Yosys mutates those objects (e.g. destroys them), the SDC plugin will
# segfault.
write_sdc -include_propagated_clocks $::env(OUT_SDC)

write_verilog $::env(OUT_SYNTH_V).premap.v

# Look for connections OSERDESE2.OQ -> OBUFDS.I. Annotate OBUFDS with a parameter
# indicating that it is connected to an OSERDESE2
select -set obufds t:OSERDESE2 %co2:+\[OQ,I\] t:OBUFDS t:OBUFTDS %u  %i
setparam -set HAS_OSERDES 1 @obufds

# Map Xilinx tech library to 7-series VPR tech library.
read_verilog -specify -lib $::env(TECHMAP_PATH)/cells_sim.v

# Convert congested CARRY4 outputs to LUTs.
#
# This is required because VPR cannot reliably resolve SLICE[LM] output
# congestion when both O and CO outputs are used. For this reason if both O
# and CO outputs are used, the CO output is computed using a LUT.
#
# Ideally VPR would resolve the congestion in one of the following ways:
#
#  - If either O or CO are registered in a FF, then no output
#    congestion exists if the O or CO FF is packed into the same cluster.
#    The register output will used the [ABCD]Q output, and the unregistered
#    output will used the [ABCD]MUX.
#
#  - If neither the O or CO are registered in a FF, then the [ABCD]Q output
#    can still be used if the FF is placed into "transparent latch" mode.
#    VPR can express this edge, but because using a FF in "transparent latch"
#    mode requires running specific CE and SR signals connected to constants,
#    VPR cannot easily (or at all) express this packing situation.
#
#    VPR's packer in theory could be expanded to express this kind of
#    situation.
#
#                                   CLE Row
#
# +--------------------------------------------------------------------------+
# |                                                                          |
# |                                                                          |
# |                                               +---+                      |
# |                                               |    +                     |
# |                                               |     +                    |
# |                                     +-------->+ O    +                   |
# |              CO CHAIN               |         |       +                  |
# |                                     |         |       +---------------------> xMUX
# |                 ^                   |   +---->+ CO    +                  |
# |                 |                   |   |     |      +                   |
# |                 |                   |   |     |     +                    |
# |       +---------+----------+        |   |     |    +                     |
# |       |                    |        |   |     +---+                      |
# |       |     CARRY ROW      |        |   |                                |
# |  +--->+ S              O   +--------+   |       xOUTMUX                  |
# |       |                    |        |   |                                |
# |       |                    |        +   |                                |
# |  +--->+ DI             CO  +-------+o+--+                                |
# |       |      CI CHAIN      |        +   |                                |
# |       |                    |        |   |                                |
# |       +---------+----------+        |   |       xFFMUX                   |
# |                 ^                   |   |                                |
# |                 |                   |   |     +---+                      |
# |                 +                   |   |     |    +                     |
# |                                     |   +     |     +    +-----------+   |
# |                                     +--+o+--->+ O    +   |           |   |
# |                                         +     |       +  |    xFF    |   |
# |                                         |     |       +->--D----   Q +------> xQ
# |                                         |     |       +  |           |   |
# |                                         +---->+ CO   +   |           |   |
# |                                               |     +    +-----------+   |
# |                                               |    +                     |
# |                                               +---+                      |
# |                                                                          |
# |                                                                          |
# +--------------------------------------------------------------------------+
#

techmap -map  $::env(TECHMAP_PATH)/carry_map.v

clean_processes
write_json $::env(OUT_JSON).carry_fixup.json

exec $::env(PYTHON3) -m f4pga.utils.xc7.fix_xc7_carry < $::env(OUT_JSON).carry_fixup.json > $::env(OUT_JSON).carry_fixup_out.json
design -push
read_json $::env(OUT_JSON).carry_fixup_out.json

techmap -map  $::env(TECHMAP_PATH)/clean_carry_map.v

# Re-read baseline libraries
read_verilog -lib -specify +/xilinx/cells_sim.v
read_verilog -lib +/xilinx/cells_xtra.v
read_verilog -specify -lib $::env(TECHMAP_PATH)/cells_sim.v
if { $::env(USE_ROI) != "TRUE" } {
    read_verilog -lib $::env(TECHMAP_PATH)/iobs.v
}

# Re-run optimization flow to absorb carry modifications
hierarchy -check

write_ilang $::env(OUT_JSON).pre_abc9.ilang
if { $::env(USE_ROI) == "TRUE" } {
    synth_xilinx -flatten -abc9 -nosrl -noclkbuf -nodsp -noiopad -nowidelut -run map_ffs:check
} else {
    synth_xilinx -flatten -abc9 -nosrl -noclkbuf -nodsp -iopad -nowidelut -run map_ffs:check
}

write_ilang $::env(OUT_JSON).post_abc9.ilang

# Either the JSON bounce or ABC9 pass causes the CARRY4_VPR CIN/CYINIT pins
# to have 0's when unused.  As a result VPR will attempt to route a 0 to those
# ports. However this is not generally possible or desirable.
#
# $::env(TECHMAP_PATH)/cells_map.v has a simple techmap pass where these
# unused ports are removed.  In theory yosys's "rmports" would work here, but
# it does not.
chtype -map CARRY4_VPR CARRY4_FIX
techmap -map  $::env(TECHMAP_PATH)/cells_map.v

# opt_expr -undriven makes sure all nets are driven, if only by the $undef
# net.
opt_expr -undriven
opt_clean

setundef -zero -params
stat

# TODO: remove this as soon as new VTR master+wip is pushed: https://github.com/SymbiFlow/vtr-verilog-to-routing/pull/525
attrmap -remove hdlname

# Write the design in JSON format.
clean_processes
write_json $::env(OUT_JSON)
# Write the design in Verilog format.
write_verilog $::env(OUT_SYNTH_V)

design -reset
exec $::env(PYTHON3) -m f4pga.utils.yosys_split_inouts -i $::env(OUT_JSON) -o $::env(SYNTH_JSON)
read_json $::env(SYNTH_JSON)
yosys -import
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
