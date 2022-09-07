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

MYPATH=`realpath $0`
MYDIR=`dirname $MYPATH`

source ${MYDIR}/../common.f4pga.sh

F4PGA_AUX_PATH=`realpath ${MYDIR}/../../../aux`
F4PGA_EXEC_TCL_PATH=${F4PGA_AUX_PATH}/tool_data/yosys/scripts/common/f4pga_exec.tcl
F4PGA_COMMON_TCL_PATH=${F4PGA_AUX_PATH}/tool_data/yosys/scripts/common/common.tcl
SYNTH_TCL_PATH=${F4PGA_AUX_PATH}/tool_data/yosys/scripts/vendor/xilinx/xc7/synth.tcl
CONV_TCL_PATH=${F4PGA_AUX_PATH}/tool_data/yosys/scripts/vendor/xilinx/xc7/conv.tcl

VERILOG_FILES=()
XDC_FILES=()
TOP=top
DEVICE="*"
PART=""
SURELOG_CMD=()

VERILOGLIST=0
XDCLIST=0
TOPNAME=0
DEVICENAME=0
PARTNAME=0
SURELOG=0

for arg in $@; do
  echo $arg
  case "$arg" in
    -v|--verilog) VERILOGLIST=1 XDCLIST=0 TOPNAME=0 DEVICENAME=0 PARTNAME=0 SURELOG=0 ;;
    -x|--xdc)     VERILOGLIST=0 XDCLIST=1 TOPNAME=0 DEVICENAME=0 PARTNAME=0 SURELOG=0 ;;
    -t|--top)     VERILOGLIST=0 XDCLIST=0 TOPNAME=1 DEVICENAME=0 PARTNAME=0 SURELOG=0 ;;
    -d|--device)  VERILOGLIST=0 XDCLIST=0 TOPNAME=0 DEVICENAME=1 PARTNAME=0 SURELOG=0 ;;
    -p|--part)    VERILOGLIST=0 XDCLIST=0 TOPNAME=0 DEVICENAME=0 PARTNAME=1 SURELOG=0 ;;
    -s|--surelog) VERILOGLIST=0 XDCLIST=0 TOPNAME=0 DEVICENAME=0 PARTNAME=0 SURELOG=1 ;;
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
      else
        echo "Usage: synth [-t|--top <top module name> -v|--verilog <Verilog files list> [-x|--xdc <XDC files list>]"
        echo "             [-d|--device <device type (e.g. artix7)>] [-p|--part <part name>] [-s|--surelog] <parameters to surelog>"
        echo "note: device and part parameters are required if xdc is passed"
        exit 1
      fi
      ;;
  esac
done

if [ ${#VERILOG_FILES[@]} -eq 0 ]; then echo "Please provide at least one Verilog file"; exit 1; fi

export TOP="${TOP}"
export USE_ROI='FALSE'
export INPUT_XDC_FILES="${XDC_FILES[*]}"
export OUT_JSON="$TOP.json"
export OUT_SDC="${TOP}.sdc"
export SYNTH_JSON="${TOP}_io.json"
export OUT_SYNTH_V="${TOP}_synth.v"
export OUT_EBLIF="${TOP}.eblif"
export PART_JSON=`realpath ${DATABASE_DIR:-$(prjxray-config)}/$DEVICE/$PART/part.json`
export OUT_FASM_EXTRA="${TOP}_fasm_extra.fasm"
export PYTHON3="${PYTHON3:-$(which python3)}"

yosys_read_cmds=""
yosys_files="${VERILOG_FILES[*]}"
if [ -n "$SURELOG_CMD" ]; then
  yosys_read_cmds="plugin -i uhdm; read_verilog_with_uhdm ${SURELOG_CMD[*]} ${VERILOG_FILES[*]}"
  yosys_files=""
fi

DATABASE_DIR=${DATABASE_DIR:-$(prjxray-config)}

if [ -z "$SURELOG_CMD" ]; then
  YOSYS_PLUGINS="uhdm"
else
  YOSYS_PLUGINS=""
fi

# Create temporary directory for temporary files used by yosys Tcl script.
TMP_DIR=`make_tmp_dir 16 yosys_tmp_legacy_`

# Emulate inputs from f4pga. See the yosys module for the context.
export VAL_top=${TOP}
export VAL_use_roi="FALSE"
export VAL_part_name=$PART
export VAL_prjxray_db=$DATABASE_DIR
export VAL_bitstream_device=$DEVICE
export VAL_python3=${PYTHON3:=$(which python3)}
export VAL_shareDir=$F4PGA_SHARE_DIR
export VAL_yosys_plugins=$YOSYS_PLUGINS
export VAL_surelog_cmd=${SURELOG_CMD[*]}
export VAL_use_lut_constants="FALSE"
export TMP_json_carry_fixup=${TMP_DIR}/json_carry_fixup.json
export TMP_json_carry_fixup_out=${TMP_DIR}/json_carry_fixup_out.json
export TMP_json_presplit=${TMP_DIR}/json_presplit.json
export DEP_sources=${VERILOG_FILES[*]}
export DEP_xdc=${XDC_FILES[*]}
export DEP_build_dir="build"
export DEP_fasm_extra=${TOP}_fasm_extra.fasm
export DEP_synth_v_premap=${TOP}_struct_premap.v
export DEP_synth_v=${TOP}_struct.v
export DEP_sdc=${TOP}.sdc
export DEP_json=$TOP.json
export DEP_synth_json=${TOP}_io.json
export DEP_rtlil_preopt=${TOP}.pre_abc9.ilang
export DEP_rtlil=${TOP}.post_abc9.ilang
export DEP_eblif=${TOP}.eblif

LOG=${TOP}_synth.log

set +e

CMDS="tcl ${F4PGA_EXEC_TCL_PATH}; tcl ${F4PGA_COMMON_TCL_PATH}; tcl ${SYNTH_TCL_PATH}"

if [ -z "$SURELOG_CMD" ]; then
  yosys -p "${CMDS}" -l $LOG
else
  yosys -p "plugin -i uhdm; ${CMDS}" -l $LOG
fi

rm -rf $TMP_DIR

RESULT=$?
if [ $RESULT != 0 ]; then
  exit $RESULT
fi

set -e
