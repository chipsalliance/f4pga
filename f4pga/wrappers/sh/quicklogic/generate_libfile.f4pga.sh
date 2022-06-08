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

ARCH_DIR="$F4PGA_ENV_SHARE"/arch/${DEVICE_1}_${DEVICE_1}
PINMAP_XML=${ARCH_DIR}/${PINMAPXML}

`which python3` "$F4PGA_ENV_BIN"/python/create_lib.py \
  -n ${DEV}_0P72_SSM40 \
  -m fpga_top \
  -c $PART \
  -x ${ARCH_DIR}/lib/${INTERFACEXML} \
  -l ${DEV}_0P72_SSM40.lib \
  -t ${ARCH_DIR}/lib
