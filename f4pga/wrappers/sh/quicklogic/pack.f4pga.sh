#!/bin/bash
set -e

MYPATH=`realpath $0`
MYPATH=`dirname ${MYPATH}`

source ${MYPATH}/env
source ${VPRPATH}/vpr_common

parse_args $@

export OUT_NOISY_WARNINGS=noisy_warnings-${DEVICE}_pack.log

run_vpr --pack

mv vpr_stdout.log pack.log
