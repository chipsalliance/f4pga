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

echo "Writing bitstream ..."

FRM2BIT=""
if [ ! -z ${FRAMES2BIT} ]; then
  FRM2BIT="--frm2bit ${FRAMES2BIT}"
fi

OPTS=d:f:b:p:
LONGOPTS=device:,fasm:,bit:,part:

PARSED_OPTS=`getopt --options=${OPTS} --longoptions=${LONGOPTS} --name $0 -- $@`
eval set -- ${PARSED_OPTS}

DEVICE=""
FASM=""
BIT=""
PART=xc7a35tcpg236-1

while true; do
  case "$1" in
    -d|--device)
      DEVICE=$2
      shift 2
      ;;
    -p|--part)
      PART=$2
      shift 2
      ;;
    -f|--fasm)
      FASM=$2
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

DATABASE_DIR=${DATABASE_DIR:=$(prjxray-config)}

if [ -z $DEVICE ]; then
  # Try to find device name. Accept only when exactly one is found
  PART_DIRS=(${DATABASE_DIR}/*/${PART})
  if [ ${#PART_DIRS[@]} -eq 1 ]; then
    DEVICE=$(basename $(dirname "${PART_DIRS[0]}"))
  else
    echo "Please provide device name"
    exit 1
  fi
fi

DBROOT=`realpath ${DATABASE_DIR}/${DEVICE}`

if [ -z $FASM ]; then
  echo "Please provide fasm file name"
  exit 1
fi

if [ -z $BIT ]; then
  echo "Please provide bit file name"
  exit 1
fi

xcfasm \
  --db-root ${DBROOT} \
  --part ${PART} \
  --part_file ${DBROOT}/${PART}/part.yaml \
  --sparse \
  --emit_pudc_b_pullup \
  --fn_in ${FASM} \
  --bit_out ${BIT} ${FRM2BIT}
