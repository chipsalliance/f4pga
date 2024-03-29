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
    -t|--top)     OPT="top" ;;
    -v|--verilog) OPT="vlog" ;;
    -d|--device)  OPT="dev" ;;
    -F|--family)  OPT="family" ;;
    -P|--part)    OPT="part" ;;
    -p|--pcf)     OPT="pcf" ;;
    -y|-f|+incdir+*|+libext+*|+define+*) OPT="xtra" ;;
    *)
      case $OPT in
        "top")    TOP=$arg;    OPT="" ;;
        "dev")    DEVICE=$arg; OPT="" ;;
        "family") FAMILY=$arg; OPT="" ;;
        "part")   PART=$arg;   OPT="" ;;
        "pcf")    PCF=$arg;    OPT="" ;;
        "vlog")   VERILOG_FILES+=($arg) ;;
        "xtra") ;;
        *) print_usage ;;
      esac
      ;;
  esac
  if [ "$OPT" == "xtra" ]; then EXTRA_ARGS+=($arg); fi
done

if [ -z ${FAMILY} ]; then echo "Please specify device family"; exit 1; fi
if [ ${#VERILOG_FILES[@]} -eq 0 ]; then echo "Please provide at least one Verilog file"; exit 1; fi

PINMAPCSV="pinmap_${PART}.csv"

export USE_ROI="FALSE"
export OUT_JSON=$TOP.json
export SYNTH_JSON=${TOP}_io.json
export OUT_SYNTH_V=${TOP}_synth.v
export OUT_EBLIF=${TOP}.eblif
export OUT_FASM_EXTRA=${TOP}_fasm_extra.fasm
export PYTHON3=$(which python3)

if [ -s $PCF ]; then
  export PCF_FILE=$PCF
else
  export PCF_FILE=""
fi

DEVICE_PATH="${F4PGA_SHARE_DIR}/arch/${DEVICE}_${DEVICE}"
export PINMAP_FILE=${DEVICE_PATH}/${PINMAPCSV}
if [ -d "${DEVICE_PATH}/cells" ]; then
  export DEVICE_CELLS_SIM=`find ${DEVICE_PATH}/cells -name "*_sim.v"`
  export DEVICE_CELLS_MAP=`find ${DEVICE_PATH}/cells -name "*_map.v"`
else
  # pp3 family has different directory naming scheme
  # the are named as ${DEVICE}_${PACKAGE}
  # ${PACKAGE} is not known because it is not passed down in add_binary_toolchain_test
  DEVICE_PATH=$(find "${F4PGA_SHARE_DIR}"/arch/ -type d -name "${DEVICE}*")
  export PINMAP_FILE=${DEVICE_PATH}/${PINMAPCSV}
  if [ -d "${DEVICE_PATH}/cells" ]; then
    export DEVICE_CELLS_SIM=`find ${DEVICE_PATH}/cells -name "*_sim.v"`
    export DEVICE_CELLS_MAP=`find ${DEVICE_PATH}/cells -name "*_map.v"`
  else
    export DEVICE_CELLS_SIM=
    export DEVICE_CELLS_MAP=
  fi
fi

yosys_cmds=`echo ${EXTRA_ARGS[*]} | python3 -m f4pga.utils.quicklogic.convert_compile_opts`
if [ ! -z "${yosys_cmds}" ]; then yosys_cmds="${yosys_cmds//$'\n'/'; '}; "; fi

yosys_read_cmds=''
for f in ${VERILOG_FILES[*]}; do
  yosys_read_cmds="read_verilog ${f}; $yosys_read_cmds"
done

`which yosys` \
  -p "$yosys_cmds $yosys_read_cmds tcl $(python3 -m f4pga.wrappers.tcl "${FAMILY}")" \
  -l "${TOP}_synth.log"
