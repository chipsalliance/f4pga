#!/bin/bash
set -e

MYPATH=`realpath $0`
MYPATH=`dirname ${MYPATH}`

source ${MYPATH}/env
source ${MYPATH}/vpr_common

parse_args "$@"

OUT_NOISY_WARNINGS=noisy_warnings-${DEVICE}_place.log

run_vpr_xml_rr_graph --pack

