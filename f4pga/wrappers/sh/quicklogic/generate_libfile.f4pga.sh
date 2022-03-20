#!/usr/bin/env bash

set -e

PART=$1
DEVICE=$2
CORNER=$3

if [[ "$DEVICE" =~ ^(qlf_k4n8_qlf_k4n8)$ ]];then
  DEVICE_1="qlf_k4n8-qlf_k4n8_umc22_$CORNER"
  PINMAPXML="pinmap_qlf_k4n8_umc22.xml"
  INTERFACEXML="interface-mapping_24x24.xml"
  DEV="qlf_k4n8_umc22"
else
  DEVICE_1=${DEVICE}
fi

ARCH_DIR=$(f4pga-env share)/arch/${DEVICE_1}_${DEVICE_1}
PINMAP_XML=${ARCH_DIR}/${PINMAPXML}

python3 $(f4pga-env bin)/python/create_lib.py \
  -n ${DEV}_0P72_SSM40 \
  -m fpga_top \
  -c $PART \
  -x ${ARCH_DIR}/lib/${INTERFACEXML} \
  -l ${DEV}_0P72_SSM40.lib \
  -t ${ARCH_DIR}/lib
