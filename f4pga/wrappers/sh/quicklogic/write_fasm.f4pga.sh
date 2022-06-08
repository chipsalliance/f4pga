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
  export PYTHONPATH=${VPRPATH}/python:${PYTHONPATH}
fi

source $(dirname "$0")/vpr_common.f4pga.sh
parse_args "$@"

TOP="${EBLIF%.*}"
FASM_EXTRA="${TOP}_fasm_extra.fasm"

export OUT_NOISY_WARNINGS=noisy_warnings-${DEVICE}_fasm.log

run_genfasm

echo "FASM extra: $FASM_EXTRA"
if [ -f $FASM_EXTRA ]; then
  echo "writing final fasm"
  cat ${TOP}.fasm $FASM_EXTRA > tmp.fasm
  mv tmp.fasm ${TOP}.fasm
fi

mv vpr_stdout.log fasm.log
