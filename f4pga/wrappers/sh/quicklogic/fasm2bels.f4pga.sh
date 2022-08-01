#!/bin/bash
#
# Copyright (C) 2020-2022 F4PGA Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

set -e

SHARE_DIR_PATH=${SHARE_DIR_PATH:="$F4PGA_SHARE_DIR"}
BIN_DIR_PATH=${BIN_DIR_PATH:="$F4PGA_BIN_DIR"}

OPTS=d:P:p:b:v:o:q
LONGOPTS=device:,part:,pcf:,bit:,out-verilog:,out-pcf:,out-qcf:,

PARSED_OPTS=`getopt --options=${OPTS} --longoptions=${LONGOPTS} --name $0 -- "$@"`
eval set -- "${PARSED_OPTS}"

DEVICE=""
PART=""
PCF=""
BIT=""
OUT_VERILOG=""
OUT_PCF=""
OUT_QCF=""

while true; do
	case "$1" in
		-d|--device)
			DEVICE=$2
			shift 2
			;;
		-P|--part)
			PART=$2
			shift 2
			;;
		-p|--pcf)
			PCF=$2
			shift 2
			;;
		-b|--bit)
			BIT=$2
			shift 2
			;;
		-v|--out-verilog)
			OUT_VERILOG=$2
			shift 2
			;;
		-o|--out-pcf)
			OUT_PCF=$2
			shift 2
			;;
		-q|--out-qcf)
			OUT_QCF=$2
			shift 2
			;;
		--)
			break
			;;
	esac
done

if [ -z $DEVICE ]; then
    echo "Please provide device name"
	exit 1
fi

if [ -z $BIT ]; then
	echo "Please provide an input bistream file name"
	exit 1
fi


# $DEVICE is not ql-eos-s3 or ql-pp3e
if ! [[ "$DEVICE" =~ ^(ql-eos-s3|ql-pp3e)$ ]]; then
    echo "ERROR: Unsupported device '${DEVICE}' for fasm2bels"
    exit -1
fi

# Run fasm2bels
VPR_DB=`readlink -f ${SHARE_DIR_PATH}/arch/${DEVICE}_wlcsp/db_phy.pickle`
FASM2BELS=`readlink -f ${SHARE_DIR_PATH}/scripts/fasm2bels.py`
FASM2BELS_DEVICE=${DEVICE/ql-/}

VERILOG_FILE="${OUT_VERILOG:-$BIT.v}"
PCF_FILE="${OUT_PCF:-$BIT.v.pcf}"
QCF_FILE="${OUT_QCF:-$BIT.v.qcf}"

if [ ! -z "{PCF}" ]; then
    PCF_ARGS="--input-pcf ${PCF}"
else
    PCF_ARGS=""
fi

echo "Running fasm2bels"
`which python3` ${FASM2BELS} ${BIT} --phy-db ${VPR_DB} --device-name ${FASM2BELS_DEVICE} --package-name ${PART} --input-type bitstream --output-verilog ${VERILOG_FILE} ${PCF_ARGS} --output-pcf ${PCF_FILE} --output-qcf ${QCF_FILE}
