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

source ${VPRPATH}/vpr_common
parse_args $@

export OUT_NOISY_WARNINGS=noisy_warnings-${DEVICE}_analysis.log

run_vpr --analysis --gen_post_synthesis_netlist on --verify_file_digests off

mv vpr_stdout.log analysis.log

python3 "$F4PGA_ENV_BIN"/python/vpr_fixup_post_synth.py \
    --vlog-in ${TOP}_post_synthesis.v \
    --vlog-out ${TOP}_post_synthesis.v \
    --sdf-in ${TOP}_post_synthesis.sdf \
    --sdf-out ${TOP}_post_synthesis.sdf \
    --split-ports
