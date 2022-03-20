#!/usr/bin/env bash

set -e

source $(dirname "$0")/vpr_common.f4pga.sh
parse_args "$@"

TOP="${EBLIF%.*}"
FASM_EXTRA=${TOP}_fasm_extra.fasm

export OUT_NOISY_WARNINGS=noisy_warnings-${DEVICE}_fasm.log

run_genfasm

echo "FASM extra: $FASM_EXTRA"
if [ -f $FASM_EXTRA ]; then
  echo "writing final fasm"
  cat ${TOP}.fasm $FASM_EXTRA > tmp.fasm
  mv tmp.fasm ${TOP}.fasm
fi

mv vpr_stdout.log fasm.log
