#!/usr/bin/env bash

set -e

PCF=$1
EBLIF=$2
NET=$3
PART=$4
DEVICE=$5
ARCH_DEF=$6
CORNER=$7

if [[ "$DEVICE" =~ ^(qlf_k4n8_qlf_k4n8)$ ]];then
  DEVICE_1="qlf_k4n8-qlf_k4n8_umc22_$CORNER"
  PINMAPXML="pinmap_qlf_k4n8_umc22.xml"
elif [[ "$DEVICE" =~ ^(qlf_k6n10_qlf_k6n10)$ ]];then
  DEVICE_1="qlf_k6n10-qlf_k6n10_gf12"
  PINMAPXML="pinmap_qlf_k6n10_gf12.xml"
else
  DEVICE_1=${DEVICE}
fi

SHARE_DIR_PATH=${SHARE_DIR_PATH:=$(f4pga-env share)}

PINMAP_XML=`realpath ${SHARE_DIR_PATH}/arch/${DEVICE_1}_${DEVICE_1}/${PINMAPXML}`

PROJECT=$(basename -- "$EBLIF")
IOPLACE_FILE="${PROJECT%.*}_io.place"

python3 $(realpath $(f4pga-env bin)/python/create_ioplace.py) \
  --pcf $PCF \
  --blif $EBLIF \
  --pinmap_xml $PINMAP_XML \
  --csv_file $PART \
  --net $NET \
  > ${IOPLACE_FILE}
