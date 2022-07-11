# For some tests the equiv_induct pass seems to hang if opt_expr + opt_clean
# are not invoked after techmapping. Therefore this function is used instead
# of the equiv_opt pass.
proc check_equiv {top use_cfg_params} {
    hierarchy -top ${top}

    design -save preopt

    if {${use_cfg_params} == 1} {
        synth_quicklogic -family qlf_k6n10f -top ${top} -use_dsp_cfg_params
    } else {
        stat
        synth_quicklogic -family qlf_k6n10f -top ${top}
    }

    design -stash postopt

    design -copy-from preopt  -as gold A:top
    design -copy-from postopt -as gate A:top

    techmap -wb -autoproc -map +/quicklogic/qlf_k6n10f/cells_sim.v
    techmap -wb -autoproc -map +/quicklogic/qlf_k6n10f/dsp_sim.v
    yosys proc
    opt_expr
    opt_clean -purge

    async2sync
    equiv_make gold gate equiv
    equiv_induct equiv
    equiv_status -assert equiv

    return
}

# Test inference of 2 available DSP variants
# * top - design name
# * expected_cell_suffix - suffix of the cell that should be the result
#           of the inference, eg. _MULT, _MACC_REGIN, MADD_REGIN_REGOUT
proc test_dsp_design {top expected_cell_suffix} {
    set TOP ${top}
    # Infer DSP with configuration bits passed through ports
    # We expect QL_DSP2 cells inferred
    set USE_DSP_CFG_PARAMS 0
    design -load read
    hierarchy -top $TOP
    check_equiv ${TOP} ${USE_DSP_CFG_PARAMS}
    design -load postopt
    yosys cd ${top}
    select -assert-count 1 t:QL_DSP2${expected_cell_suffix}
    select -assert-count 1 t:*

    # Infer DSP with configuration bits passed through parameters
    # We expect QL_DSP3 cells inferred
    set USE_DSP_CFG_PARAMS 1
    design -load read
    hierarchy -top $TOP
    check_equiv ${TOP} ${USE_DSP_CFG_PARAMS}
    design -load postopt
    yosys cd ${TOP}
    select -assert-count 1 t:QL_DSP3${expected_cell_suffix}
    select -assert-count 1 t:*

    return
}

yosys -import
if { [info procs quicklogic_eqn] == {} } { plugin -i ql-qlf}
yosys -import  ;# ingest plugin commands

read_verilog dsp_macc.v
design -save read

test_dsp_design "macc_simple"               "_MULTACC"
test_dsp_design "macc_simple_clr"           "_MULTACC"
test_dsp_design "macc_simple_arst"          "_MULTACC"
test_dsp_design "macc_simple_ena"           "_MULTACC"
test_dsp_design "macc_simple_arst_clr_ena"  "_MULTACC"
test_dsp_design "macc_simple_preacc"        "_MULTADD"
test_dsp_design "macc_simple_preacc_clr"    "_MULTADD"

