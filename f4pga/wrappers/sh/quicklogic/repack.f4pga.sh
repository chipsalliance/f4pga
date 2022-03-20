#!/usr/bin/env bash

set -e

if [ -z $VPRPATH ]; then
  export VPRPATH=$(f4pga-env bin)
  export PYTHONPATH=${VPRPATH}/python:${VPRPATH}/python/prjxray:${PYTHONPATH}
fi

source ${VPRPATH}/vpr_common
parse_args $@

DESIGN=${EBLIF/.eblif/}

[ ! -z "${JSON}" ] && JSON_ARGS="--json-constraints ${JSON}" || JSON_ARGS=
[ ! -z "${PCF_PATH}" ] && PCF_ARGS="--pcf-constraints ${PCF_PATH}" || PCF_ARGS=

python3 $(f4pga-env bin)/python/repacker/repack.py \
  --vpr-arch ${ARCH_DEF} \
  --repacking-rules ${ARCH_DIR}/${DEVICE_1}.repacking_rules.json \
  $JSON_ARGS \
  $PCF_ARGS \
  --eblif-in ${DESIGN}.eblif \
  --net-in ${DESIGN}.net \
  --place-in ${DESIGN}.place \
  --eblif-out ${DESIGN}.repacked.eblif \
  --net-out ${DESIGN}.repacked.net \
  --place-out ${DESIGN}.repacked.place \
  --absorb_buffer_luts on \
  >repack.log 2>&1
