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

VERILOG_FILES=()
XDC_FILES=()
TOP=top
DEVICE="*"
PART=""
SURELOG_CMD=()
DEFINE_LIST=()

VERILOGLIST=0
XDCLIST=0
TOPNAME=0
DEVICENAME=0
PARTNAME=0
SURELOG=0
DEFINES=0

for arg in $@; do
  echo $arg
  case "$arg" in
  -v | --verilog) VERILOGLIST=1 XDCLIST=0 TOPNAME=0 DEVICENAME=0 PARTNAME=0 SURELOG=0 DEFINES=0 ;;
  -x | --xdc) VERILOGLIST=0 XDCLIST=1 TOPNAME=0 DEVICENAME=0 PARTNAME=0 SURELOG=0 DEFINES=0 ;;
  -t | --top) VERILOGLIST=0 XDCLIST=0 TOPNAME=1 DEVICENAME=0 PARTNAME=0 SURELOG=0 DEFINES=0 ;;
  -d | --device) VERILOGLIST=0 XDCLIST=0 TOPNAME=0 DEVICENAME=1 PARTNAME=0 SURELOG=0 DEFINES=0 ;;
  -p | --part) VERILOGLIST=0 XDCLIST=0 TOPNAME=0 DEVICENAME=0 PARTNAME=1 SURELOG=0 DEFINES=0 ;;
  -s | --surelog) VERILOGLIST=0 XDCLIST=0 TOPNAME=0 DEVICENAME=0 PARTNAME=0 SURELOG=1 DEFINES=0 ;;
  -e | --defines) VERILOGLIST=0 XDCLIST=0 TOPNAME=0 DEVICENAME=0 PARTNAME=0 SURELOG=0 DEFINES=1 ;;
  *)
    if [ $VERILOGLIST -eq 1 ]; then
      VERILOG_FILES+=($arg)
    elif [ $XDCLIST -eq 1 ]; then
      XDC_FILES+=($arg)
    elif [ $TOPNAME -eq 1 ]; then
      TOP=$arg
    elif [ $DEVICENAME -eq 1 ]; then
      DEVICE=$arg
    elif [ $PARTNAME -eq 1 ]; then
      PART=$arg
    elif [ $SURELOG -eq 1 ]; then
      SURELOG_CMD+=($arg)
    elif [ $DEFINES -eq 1 ]; then
      DEFINE_LIST+=($arg)
    else
      echo "Usage: synth [-t|--top <top module name> -v|--verilog <Verilog files list> [-x|--xdc <XDC files list>]"
      echo "             [-d|--device <device type (e.g. artix7)>] [-p|--part <part name>] [-s|--surelog] <parameters to surelog>"
      echo "note: device and part parameters are required if xdc is passed"
      exit 1
    fi
    ;;
  esac
done

if [ ${#VERILOG_FILES[@]} -eq 0 ]; then
  echo "Please provide at least one Verilog file"
  exit 1
fi
DEFINE_ARGS=()
if [ ${#DEFINE_LIST[@]} -ne 0 ]; then
  for define in "${DEFINE_LIST[@]}"; do
    DEFINE_ARGS+=("-D$define")
  done
fi

export TOP="${TOP}"
export USE_ROI='FALSE'
export INPUT_XDC_FILES="${XDC_FILES[*]}"
export OUT_JSON="$TOP.json"
export OUT_SDC="${TOP}.sdc"
export SYNTH_JSON="${TOP}_io.json"
export OUT_SYNTH_V="${TOP}_synth.v"
export OUT_EBLIF="${TOP}.eblif"
export PART_JSON=$(realpath ${DATABASE_DIR:-$(prjxray-config)}/$DEVICE/$PART/part.json)
export OUT_FASM_EXTRA="${TOP}_fasm_extra.fasm"
export PYTHON3="${PYTHON3:-$(which python3)}"

yosys_read_cmds=""
yosys_files="${VERILOG_FILES[*]}"
if [ -n "$SURELOG_CMD" ]; then
  yosys_read_cmds="plugin -i systemverilog; read_systemverilog ${SURELOG_CMD[*]} ${VERILOG_FILES[*]}"
  yosys_files=""
fi
echo yosys \
  -p "$yosys_read_cmds; tcl $(python3 -m f4pga.wrappers.tcl)" \
  -l "${TOP}_synth.log" \
  "${DEFINE_ARGS[*]}" \
  $yosys_files
