#!/bin/bash
set -e

MYPATH=`realpath $0`
MYPATH=`dirname ${MYPATH}`

source ${MYPATH}/env
source ${VPRPATH}/vpr_common

parse_args $@

FIXUP_POST_SYNTHESIS=`realpath ${MYPATH}/python/vpr_fixup_post_synth.py`

export OUT_NOISY_WARNINGS=noisy_warnings-${DEVICE}_analysis.log

run_vpr --analysis --gen_post_synthesis_netlist on --verify_file_digests off

mv vpr_stdout.log analysis.log

python3 ${FIXUP_POST_SYNTHESIS} \
    --vlog-in ${TOP}_post_synthesis.v \
    --vlog-out ${TOP}_post_synthesis.v \
    --sdf-in ${TOP}_post_synthesis.sdf \
    --sdf-out ${TOP}_post_synthesis.sdf \
    --split-ports
