#!/bin/bash
set -e

MYPATH=`realpath $0`
MYPATH=`dirname ${MYPATH}`

source ${MYPATH}/env
source ${VPRPATH}/vpr_common

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
