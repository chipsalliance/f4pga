#!/usr/bin/env bash

set -e

source $(dirname "$0")/vpr_common.f4pga.sh
parse_args "$@"

export OUT_NOISY_WARNINGS=noisy_warnings-${DEVICE}_pack.log

run_vpr --pack
mv vpr_stdout.log pack.log
