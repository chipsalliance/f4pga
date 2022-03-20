#!/usr/bin/env bash

set -e

if [ -z $VPRPATH ]; then
  export VPRPATH=$(f4pga-env bin)
  export PYTHONPATH=${VPRPATH}/python:${VPRPATH}/python/prjxray:${PYTHONPATH}
fi

source ${VPRPATH}/vpr_common
parse_args $@

export OUT_NOISY_WARNINGS=noisy_warnings-${DEVICE}_pack.log

run_vpr --pack

mv vpr_stdout.log pack.log
