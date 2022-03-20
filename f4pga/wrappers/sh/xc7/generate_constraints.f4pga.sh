#!/bin/bash
set -e

EBLIF=$1
NET=$2
PART=$3
DEVICE=$4
ARCH_DEF=$5
PCF=$6

if [ ! -z $PCF ]; then
    PCF_OPTS="--pcf $PCF"
fi

SHARE_DIR_PATH=${SHARE_DIR_PATH:=$(f4pga-env share)}

PROJECT=$(basename -- "$EBLIF")
IOPLACE_FILE="${PROJECT%.*}.ioplace"

python3 ${SHARE_DIR_PATH}/scripts/prjxray_create_ioplace.py \
  --blif $EBLIF \
  --map ${SHARE_DIR_PATH}/arch/${DEVICE}/${PART}/pinmap.csv \
  --net $NET $PCF_OPTS \
  > ${IOPLACE_FILE}

python3 ${SHARE_DIR_PATH}/scripts/prjxray_create_place_constraints.py \
  --net $NET \
  --arch ${ARCH_DEF} \
  --blif $EBLIF \
  --vpr_grid_map ${SHARE_DIR_PATH}/arch/${DEVICE}/vpr_grid_map.csv \
  --input ${IOPLACE_FILE} \
  --db_root ${DATABASE_DIR:=$(prjxray-config)} \
  --part $PART \
  > constraints.place
