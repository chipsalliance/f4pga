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

EBLIF=$1
NET=$2
PART=$3
DEVICE=$4
ARCH_DEF=$5
PCF=$6

if [ ! -z $PCF ]; then
    PCF_OPTS="--pcf $PCF"
fi

SHARE_DIR_PATH=${SHARE_DIR_PATH:="$F4PGA_ENV_SHARE"}

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
