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

MYPATH=`realpath $0`
MYPATH=`dirname ${MYPATH}`

OPTS=d:P:p:b:
LONGOPTS=device:,part:,pcf:,bit:,

PARSED_OPTS=`getopt --options=${OPTS} --longoptions=${LONGOPTS} --name $0 -- "$@"`
eval set -- "${PARSED_OPTS}"

DEVICE=""
PART=""
PCF=""
BIT=""

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


# Run fasm2bels
if [[ "$DEVICE" =~ ^(ql-eos-s3|ql-pp3e)$ ]]; then

    VPR_DB=`readlink -f ${MYPATH}/../share/symbiflow/arch/${DEVICE}_wlcsp/db_phy.pickle`
    FASM2BELS=`readlink -f ${MYPATH}/../bin/python/fasm2bels.py`
    FASM2BELS_DEVICE=${DEVICE/ql-/}
    VERILOG_FILE="${BIT}.v"
    PCF_FILE="${BIT}.v.pcf"
    QCF_FILE="${BIT}.v.qcf"

    if [ ! -z "{PCF}" ]; then
        PCF_ARGS="--input-pcf ${PCF}"
    else
        PCF_ARGS=""
    fi

    echo "Running fasm2bels"
    python3 ${FASM2BELS} ${BIT} --phy-db ${VPR_DB} --package-name ${PART} --input-type bitstream --output-verilog ${VERILOG_FILE} ${PCF_ARGS} --output-pcf ${PCF_FILE} --output-qcf ${QCF_FILE}

else

    echo "ERROR: Unsupported device '${DEVICE}' for fasm2bels"
    exit -1
fi
