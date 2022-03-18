#!/bin/bash
set -e

MYPATH=`realpath $0`
MYPATH=`dirname ${MYPATH}`

source ${MYPATH}/env
source ${MYPATH}/vpr_common

parse_args "$@"

if [ -z $PCF ]; then
    PCF=""
fi

if [ -z $NET ]; then
     echo "Please provide net file name"
     exit 1
fi

OUT_NOISY_WARNINGS=noisy_warnings-${DEVICE}_place.log

echo "Generating coinstrains ..."
symbiflow_generate_constraints $EBLIF $NET $PART $DEVICE $ARCH_DEF $PCF

run_vpr --fix_clusters constraints.place --place

mv vpr_stdout.log place.log
