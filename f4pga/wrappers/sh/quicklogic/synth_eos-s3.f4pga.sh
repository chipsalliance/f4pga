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

export SHARE_DIR_PATH=${SHARE_DIR_PATH:="$F4PGA_SHARE_DIR"}

export UTILS_PATH=${SHARE_DIR_PATH}/scripts

F4PGA_AUX_PATH=`realpath ${MYDIR}/../../../auxiliary`
F4PGA_EXEC_TCL_PATH=${F4PGA_AUX_PATH}/tool_data/yosys/scripts/common/f4pga_exec.tcl
F4PGA_COMMON_TCL_PATH=${F4PGA_AUX_PATH}/tool_data/yosys/scripts/common/common.tcl
SYNTH_TCL_PATH=${F4PGA_AUX_PATH}/tool_data/yosys/scripts/vendor/quicklogic/pp3/synth.tcl
CONV_TCL_PATH=${F4PGA_AUX_PATH}/tool_data/yosys/scripts/vendor/quicklogic/pp3/conv.tcl

VPRPATH=${VPRPATH:="$F4PGA_BIN_DIR"}
CONVERT_OPTS=`realpath ${SHARE_DIR_PATH}/scripts/convert_compile_opts.py`

print_usage () {
    echo "Usage: symbiflow_synth  -v|--verilog <Verilog file list>"
    echo "                       [-t|--top <top module name>]"
    echo "                       [-F|--family <device family>]"
    echo "                       [-d|--device <device type (e.g. qlf_k4n8)>]"
    echo "                       [-P|--part <part name>]"
    echo "                       [-p|--pcf <PCF IO constraints>]"
    echo "                       [-y <Verilog library search path>"
    echo "                       [+libext+<Verilog library file extension>]"
    echo "                       [+incdir+<Verilog include path>]"
    echo "                       [+define+<macro name>[=<macro value>]]"
    echo "                       [-f <additional compile command file>]"
    echo ""
    exit 1
}

VERILOG_FILES=()
TOP="top"
DEVICE=""
FAMILY=""
PART=""
PCF=""
EXTRA_ARGS=()

OPT=""
for arg in $@; do
    case $arg in
        -t|--top)
            OPT="top"
            ;;
        -v|--verilog)
            OPT="vlog"
            ;;
        -d|--device)
            OPT="dev"
            ;;
        -F|--family)
            OPT="family"
            ;;
        -P|--part)
            OPT="part"
            ;;
        -p|--pcf)
            OPT="pcf"
            ;;
        -y|-f|+incdir+*|+libext+*|+define+*)
            OPT="xtra"
            ;;
        *)
            case $OPT in
                "top")
                    TOP=$arg
                    OPT=""
                    ;;
                "vlog")
                    VERILOG_FILES+=($arg)
                    ;;
                "dev")
                    DEVICE=$arg
                    OPT=""
                    ;;
                "family")
                    FAMILY=$arg
                    OPT=""
                    ;;
                "part")
                    PART=$arg
                    OPT=""
                    ;;
                "pcf")
                    PCF=$arg
                    OPT=""
                    ;;
                "xtra")
                    ;;
                *)
                    print_usage
                    ;;
            esac
            ;;
    esac

    if [ "$OPT" == "xtra" ]; then
        EXTRA_ARGS+=($arg)
    fi

done

if [ -z ${FAMILY} ]; then
    echo "Please specify device family"
    exit 1
fi

if [ ${#VERILOG_FILES[@]} -eq 0 ]; then
  echo "Please provide at least one Verilog file"
  exit 1
fi

PINMAPCSV="pinmap_${PART}.csv"

TMP_DIR=`make_tmp_dir 16 yosys_tmp_legacy_`

export TECHMAP_PATH="${SHARE_DIR_PATH}/techmaps/${FAMILY}"

DEVICE_PATH="${SHARE_DIR_PATH}/arch/${DEVICE}_wlcsp"

export VAL_top=$TOP
export VAL_part_name=${PART}
export VAL_python3=${PYHON3:=$(which python3)}
export VAL_shareDir=$SHARE_DIR_PATH
export VAL_yosys_plugins=$YOSYS_PLUGINS
export VAL_surelog_cmd=${SURELOG_CMD[*]}
export VAL_pinmap=${DEVICE_PATH}/${PINMAPCSV}
export TMP_json_org=${TMP_DIR}/json_org.json
export TMP_json_presplit=${TMP_DIR}/json_premapped.json
export DEP_sources=${VERILOG_FILES[*]}
export DEP_build_dir="build"
export DEP_json=${TOP}.json
export DEP_synth_json=${TOP}_io.json
export DEP_pcf=$PCF
export DEP_synth_v_premap=${TOP}_struct_premap.v
export DEP_eblif=${TOP}.eblif

LOG=${TOP}_synth.log


YOSYS_COMMANDS=`echo ${EXTRA_ARGS[*]} | python3 ${CONVERT_OPTS}`
YOSYS_COMMANDS="${YOSYS_COMMANDS//$'\n'/'; '}"

LOG=${TOP}_synth.log

set +e

CMDS="tcl ${F4PGA_EXEC_TCL_PATH}; tcl ${F4PGA_COMMON_TCL_PATH}; tcl ${SYNTH_TCL_PATH}"

if [ -z "$SURELOG_CMD" ]; then
  yosys -p "plugin -i ql-iob; plugin -i ql-qlf; ${CMDS}" -l $LOG
else
  yosys -p "plugin -i ql-iob; plugin -i ql-qlf; plugin -i uhdm; ${TCL}" -l $LOG
fi

rm -rf $TMP_DIR

RESULT=$?
if [ $RESULT != 0 ]; then
  exit $RESULT
fi

set -e
