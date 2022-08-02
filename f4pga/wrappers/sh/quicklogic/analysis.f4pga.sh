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

source $(dirname "$0")/env
source $(dirname "$0")/vpr_common.f4pga.sh
parse_args $@

export OUT_NOISY_WARNINGS=noisy_warnings-${DEVICE}_analysis.log

run_vpr \
  --analysis \
  --gen_post_synthesis_netlist on \
  --gen_post_implementation_merged_netlist on \
  --post_synth_netlist_unconn_inputs nets \
  --post_synth_netlist_unconn_outputs nets \
  --verify_file_digests off

mv vpr_stdout.log analysis.log
