#!/usr/bin/env bash

set -e

if [ -z $VPRPATH ]; then
  export VPRPATH=$(f4pga-env bin)
  export PYTHONPATH=${VPRPATH}/python:${VPRPATH}/python/prjxray:${PYTHONPATH}
fi

source ${VPRPATH}/vpr_common
parse_args $@

if [ -z $PCF ]; then
  echo "Please provide pcf file name"
  exit 1
fi

if [ -z $NET ]; then
  echo "Please provide net file name"
  exit 1
fi

OUT_NOISY_WARNINGS=noisy_warnings-${DEVICE}_place.log
PROJECT=$(basename -- "$EBLIF")
PLACE_FILE="${PROJECT%.*}_constraints.place"

if [ -s $PCF ]; then
  # Generate IO constraints
  echo "Generating constraints ..."
  symbiflow_generate_constraints $PCF $EBLIF $NET $PART $DEVICE $ARCH_DEF $CORNER
  if [ -f ${PLACE_FILE} ]; then
    VPR_PLACE_FILE=${PLACE_FILE}
  else
    VPR_PLACE_FILE="${PROJECT%.*}_io.place"
  fi
else
  # Make a dummy empty constraint file
  touch ${PLACE_FILE}
  VPR_PLACE_FILE=${PLACE_FILE}
fi

run_vpr --fix_clusters ${VPR_PLACE_FILE} --place

mv vpr_stdout.log place.log
