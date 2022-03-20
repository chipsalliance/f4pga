#!/usr/bin/env bash

set -e

if [ -z $VPRPATH ]; then
  export VPRPATH=$(f4pga-env bin)
  export PYTHONPATH=${VPRPATH}/python:${VPRPATH}/python/prjxray:${PYTHONPATH}
fi

source ${VPRPATH}/vpr_common
parse_args $@

export OUT_NOISY_WARNINGS=noisy_warnings-${DEVICE}_analysis.log

run_vpr --analysis --gen_post_synthesis_netlist on --verify_file_digests off

mv vpr_stdout.log analysis.log

python3 $(f4pga-env bin)/python/vpr_fixup_post_synth.py \
    --vlog-in ${TOP}_post_synthesis.v \
    --vlog-out ${TOP}_post_synthesis.v \
    --sdf-in ${TOP}_post_synthesis.sdf \
    --sdf-out ${TOP}_post_synthesis.sdf \
    --split-ports
