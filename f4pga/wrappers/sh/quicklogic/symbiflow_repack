#!/bin/bash
set -e

MYPATH=`realpath $0`
MYPATH=`dirname ${MYPATH}`

source ${MYPATH}/env
source ${VPRPATH}/vpr_common

parse_args $@

REPACK=`realpath ${MYPATH}/python/repacker/repack.py`

DESIGN=${EBLIF/.eblif/}
RULES=${ARCH_DIR}/${DEVICE_1}.repacking_rules.json

JSON_ARGS=
if [ ! -z "${JSON}" ]; then
  JSON_ARGS="--json-constraints ${JSON}"
fi

PCF_ARGS=
if [ ! -z "${PCF_PATH}" ]; then
  PCF_ARGS="--pcf-constraints ${PCF_PATH}"
fi

python3 ${REPACK} \
  --vpr-arch ${ARCH_DEF} \
  --repacking-rules ${RULES} \
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
