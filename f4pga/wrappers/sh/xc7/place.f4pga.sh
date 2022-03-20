#!/usr/bin/env bash

set -e

source $(dirname "$0")/vpr_common.f4pga.sh
parse_args "$@"

PCF=${PCF:=}

if [ -z $NET ]; then
   echo "Please provide net file name"
   exit 1
fi

export OUT_NOISY_WARNINGS=noisy_warnings-${DEVICE}_place.log

echo "Generating coinstrains ..."
symbiflow_generate_constraints $EBLIF $NET $PART $DEVICE $ARCH_DEF $PCF

run_vpr --fix_clusters constraints.place --place

mv vpr_stdout.log place.log
