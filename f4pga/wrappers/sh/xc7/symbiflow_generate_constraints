#!/bin/bash
set -e

MYPATH=`realpath $0`
MYPATH=`dirname ${MYPATH}`

export SHARE_DIR_PATH=`realpath ${MYPATH}/../share/symbiflow`

EBLIF=$1
NET=$2
PART=$3
DEVICE=$4
ARCH_DEF=$5
PCF=$6

if [ ! -z $PCF ]; then
    PCF_OPTS="--pcf $PCF"
fi

DATABASE_DIR=${DATABASE_DIR:=$(prjxray-config)}
VPR_GRID_MAP=${SHARE_DIR_PATH}/arch/${DEVICE}/vpr_grid_map.csv
PINMAP=${SHARE_DIR_PATH}/arch/${DEVICE}/${PART}/pinmap.csv
IOGEN=${SHARE_DIR_PATH}/scripts/prjxray_create_ioplace.py
CONSTR_GEN=${SHARE_DIR_PATH}/scripts/prjxray_create_place_constraints.py
PROJECT=$(basename -- "$EBLIF")
IOPLACE_FILE="${PROJECT%.*}.ioplace"

python3 ${IOGEN} --blif $EBLIF --map $PINMAP --net $NET $PCF_OPTS > ${IOPLACE_FILE}
python3 ${CONSTR_GEN} --net $NET --arch ${ARCH_DEF} --blif $EBLIF --vpr_grid_map ${VPR_GRID_MAP} --input ${IOPLACE_FILE} --db_root $DATABASE_DIR --part $PART > constraints.place

