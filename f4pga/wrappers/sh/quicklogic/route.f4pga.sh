#!/bin/bash
set -e

MYPATH=`realpath $0`
MYPATH=`dirname ${MYPATH}`

source ${MYPATH}/env
source ${VPRPATH}/vpr_common

parse_args $@

export OUR_NOISY_WARNINGS=noisy_warnings-${DEVICE}_pack.log

run_vpr --route

mv vpr_stdout.log route.log
