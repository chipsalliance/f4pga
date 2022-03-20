#!/usr/bin/env bash

set -e

source $(dirname "$0")/vpr_common.f4pga.sh
parse_args "$@"

OUT_NOISY_WARNINGS=noisy_warnings-${DEVICE}_place.log

run_vpr_xml_rr_graph --pack
