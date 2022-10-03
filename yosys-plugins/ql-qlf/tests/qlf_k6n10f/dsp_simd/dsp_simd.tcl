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
    opt_clean

    async2sync
    equiv_make gold gate equiv
    equiv_induct equiv
    equiv_status -assert equiv

    return
}

# Test inference of DSP variant
# Infer DSP with configuration bits passed through ports
# We expect QL_DSP2 cells
# * top - design name
# * expected_cell_suffix - suffix of the cell that should be the result
#           of the inference, eg. _MULT, _MACC_REGIN, MADD_REGIN_REGOUT
# * cells2match - how much expected cells should be asserted
proc test_dsp_cfg_ports {top expected_cell_suffix cells2match} {
    set TOP ${top}
    set USE_DSP_CFG_PARAMS 0
    design -load read
    hierarchy -top $TOP
    check_equiv ${TOP} ${USE_DSP_CFG_PARAMS}
    design -load postopt
    yosys cd ${top}
    select -assert-count ${cells2match} t:QL_DSP2${expected_cell_suffix}
    select -assert-count 0 t:dsp_t1_10x9x32_cfg_ports
    select -assert-count 0 t:dsp_t1_20x18x64_cfg_ports

    return
}

# Test inference of DSP variant
# Infer DSP with configuration bits passed through parameters
# We expect QL_DSP3 cells inferred
# * top - design name
# * expected_cell_suffix - suffix of the cell that should be the result
#           of the inference, eg. _MULT, _MACC_REGIN, MADD_REGIN_REGOUT
# * cells2match - how much expected cells should be asserted
proc test_dsp_cfg_params {top expected_cell_suffix cells2match} {
    set TOP ${top}
    set USE_DSP_CFG_PARAMS 1
    design -load read
    hierarchy -top $TOP
    check_equiv ${TOP} ${USE_DSP_CFG_PARAMS}
    design -load postopt
    yosys cd ${TOP}
    select -assert-count ${cells2match} t:QL_DSP3${expected_cell_suffix}
    select -assert-count 0 t:dsp_t1_10x9x32_cfg_params
    select -assert-count 0 t:dsp_t1_20x18x64_cfg_params

    return
}

# Test special case of inference of DSP
# Infer DSPs with configuration bits conflict
# One internal module use parameters, the other one ports
# We expect one QL_DSP2 and one QL_DSP3 inferred
# * top - design name
# * expected_cell_suffix - suffix of the cell that should be the result
#           of the inference, eg. _MULT, _MACC_REGIN, MADD_REGIN_REGOUT
proc test_dsp_cfg_conflict {top expected_cell_suffix} {
    set TOP ${top}
    set USE_DSP_CFG_PARAMS 0
    design -load read
    hierarchy -top $TOP
    check_equiv ${TOP} ${USE_DSP_CFG_PARAMS}
    design -load postopt
    yosys cd ${TOP}
    select -assert-count 2 t:QL_DSP2${expected_cell_suffix}
    select -assert-count 0 t:dsp_t1_10x9x32_cfg_ports
    select -assert-count 0 t:dsp_t1_20x18x64_cfg_ports
    select -assert-count 0 t:dsp_t1_10x9x32_cfg_params
    select -assert-count 0 t:dsp_t1_20x18x64_cfg_params

    return
}
yosys -import
if { [info procs quicklogic_eqn] == {} } { plugin -i ql-qlf}
yosys -import  ;# ingest plugin commands

read_verilog dsp_simd.v
design -save read

test_dsp_cfg_ports      "simd_mult_explicit_ports"      ""       1
test_dsp_cfg_params     "simd_mult_explicit_params"     ""       1
test_dsp_cfg_ports      "simd_mult_inferred"            "_MULT"  1
test_dsp_cfg_params     "simd_mult_inferred"            "_MULT"  1
test_dsp_cfg_ports      "simd_mult_odd_ports"           ""       2
test_dsp_cfg_params     "simd_mult_odd_params"          ""       2
test_dsp_cfg_ports      "simd_mult_conflict_ports"      ""       2
test_dsp_cfg_conflict   "simd_mult_conflict_config"     ""

