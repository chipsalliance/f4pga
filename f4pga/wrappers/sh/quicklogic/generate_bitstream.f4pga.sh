#!/usr/bin/env bash
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

OPTS=d:f:r:b:P:
LONGOPTS=device:,fasm:,format:,bit:,part:

PARSED_OPTS=`getopt --options=${OPTS} --longoptions=${LONGOPTS} --name $0 -- "$@"`
eval set -- "${PARSED_OPTS}"

DEVICE=""
FASM=""
BIT=""
BIT_FORMAT="4byte"
PART=""

while true; do
  case "$1" in
    -d|--device) DEVICE=$2;     shift 2;;
    -f|--fasm)   FASM=$2;       shift 2;;
    -r|--format) BIT_FORMAT=$2; shift 2;;
    -b|--bit)    BIT=$2;        shift 2;;
    -P|--part)   PART=$2;       shift 2;;
    --) break;;
  esac
done

if [ -z $DEVICE ]; then
  echo "Please provide device name"
  exit 1
fi

if [ -z $FASM ]; then
  echo "Please provide an input FASM file name"
  exit 1
fi

if [ -z $BIT ]; then
  echo "Please provide an output bistream file name"
  exit 1
fi

DB_ROOT="$F4PGA_ENV_SHARE"/fasm_database/${DEVICE}

# qlf
if [[ "$DEVICE" =~ ^(qlf_k4n8.*)$ ]]; then
    QLF_FASM=`which qlf_fasm`
    DB_ROOT=`realpath ${MYPATH}/../share/symbiflow/fasm_database/${DEVICE}`
    ${QLF_FASM} --db-root ${DB_ROOT} --format ${BIT_FORMAT} --assemble $FASM $BIT
elif [[ "$DEVICE" =~ ^(ql-eos-s3|ql-pp3e)$ ]]; then
    qlfasm --dev-type ${DEVICE} ${FASM} ${BIT}
else
    echo "ERROR: Unsupported device '${DEVICE}' for bitstream generation"
    exit -1
fi
