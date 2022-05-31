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

if [ -z $VPRPATH ]; then
  export VPRPATH="$F4PGA_ENV_BIN"
  export PYTHONPATH=${VPRPATH}/python:${VPRPATH}/python/prjxray:${PYTHONPATH}
fi

source $(dirname "$0")/vpr_common.f4pga.sh
parse_args $@

if [ -z $PCF ]; then
  echo "Please provide pcf file name"
  exit 1
fi

if [ -z $NET ]; then
  echo "Please provide net file name"
  exit 1
fi

OUT_NOISY_WARNINGS=noisy_warnings-${DEVICE}_place.log
PROJECT=$(basename -- "$EBLIF")
PLACE_FILE="${PROJECT%.*}_constraints.place"

if [ -s $PCF ]; then
  # Generate IO constraints
  echo "Generating constraints ..."
  symbiflow_generate_constraints $PCF $EBLIF $NET $PART $DEVICE $ARCH_DEF $CORNER
  if [ -f ${PLACE_FILE} ]; then
    VPR_PLACE_FILE=${PLACE_FILE}
  else
    VPR_PLACE_FILE="${PROJECT%.*}_io.place"
  fi
else
  # Make a dummy empty constraint file
  touch ${PLACE_FILE}
  VPR_PLACE_FILE=${PLACE_FILE}
fi

run_vpr --fix_clusters ${VPR_PLACE_FILE} --place

mv vpr_stdout.log place.log
