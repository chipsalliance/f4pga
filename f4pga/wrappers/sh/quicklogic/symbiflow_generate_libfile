#!/bin/bash
set -e

MYPATH=`realpath $0`
MYPATH=`dirname ${MYPATH}`

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

ARCH_DIR=`realpath ${MYPATH}/../share/symbiflow/arch/${DEVICE_1}_${DEVICE_1}`
PINMAP_XML=`realpath ${ARCH_DIR}/${PINMAPXML}`
INTF_XML=`realpath ${ARCH_DIR}/lib/${INTERFACEXML}`
CREATE_LIB=`realpath ${MYPATH}/python/create_lib.py`

python3 ${CREATE_LIB} -n ${DEV}_0P72_SSM40 -m fpga_top -c $PART -x $INTF_XML -l ${DEV}_0P72_SSM40.lib -t ${ARCH_DIR}/lib
