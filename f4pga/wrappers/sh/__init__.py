#!/usr/bin/env python3
# -*- coding: utf-8 -*-
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
#
# Python entrypoints to the shell wrappers moved from arch-defs

from sys import argv as sys_argv, stdout, stderr
from os import environ
from pathlib import Path
from shutil import which
from subprocess import check_call


f4pga_environ = environ.copy()

ROOT = Path(__file__).resolve().parent
FPGA_FAM = f4pga_environ.get('FPGA_FAM', 'xc7')
isQuickLogic = FPGA_FAM == 'eos-s3'
SH_SUBDIR = 'quicklogic' if isQuickLogic else FPGA_FAM

F4PGA_INSTALL_DIR = f4pga_environ.get('F4PGA_INSTALL_DIR')
if F4PGA_INSTALL_DIR is None:
    raise(Exception("Required environment variable F4PGA_INSTALL_DIR is undefined!"))
F4PGA_INSTALL_DIR_PATH = Path(F4PGA_INSTALL_DIR)

f4pga_environ['F4PGA_SHARE_DIR'] = f4pga_environ.get('F4PGA_SHARE_DIR', str(F4PGA_INSTALL_DIR_PATH / FPGA_FAM / 'share/f4pga'))


# Helper functions

def run_sh_script(script):
    stdout.flush()
    stderr.flush()
    check_call([str(script)]+sys_argv[1:], env=f4pga_environ)

def run_bash_cmds(cmds):
    stdout.flush()
    stderr.flush()
    check_call(cmds, env=f4pga_environ, shell=True, executable='/bin/bash')

def run_pym(module):
    stdout.flush()
    stderr.flush()
    check_call([which('python3'), '-m' , module]+sys_argv[1:], env=f4pga_environ)

def vpr_common_cmds(log_suffix = None):
    return f"""
set -e
source {ROOT / SH_SUBDIR}/vpr_common.f4pga.sh
parse_args {' '.join(sys_argv[1:])}
""" + (f"""
export OUT_NOISY_WARNINGS=noisy_warnings-${{DEVICE}}_{log_suffix}.log
""" if log_suffix is not None else '')


# Entrypoints

def generate_constraints():
    print("[F4PGA] Running (deprecated) generate constraints")
    if isQuickLogic:
        run_sh_script(ROOT / SH_SUBDIR / "generate_constraints.f4pga.sh")
    else:
        (eblif, net, part, device, arch_def) = sys_argv[1:6]
        pcf_opts = f"PCF_OPTS='--pcf {sys_argv[6]}'" if len(sys_argv) > 6 else ''
        run_bash_cmds(f"""
set -e
EBLIF='{eblif}'
NET='{net}'
PART='{part}'
DEVICE='{device}'
ARCH_DEF='{arch_def}'
{pcf_opts}
""" + """
SHARE_DIR_PATH=${SHARE_DIR_PATH:="$F4PGA_SHARE_DIR"}
PROJECT=$(basename -- "$EBLIF")
IOPLACE_FILE="${PROJECT%.*}.ioplace"

python3 "${SHARE_DIR_PATH}"/scripts/prjxray_create_ioplace.py \
  --blif "$EBLIF" \
  --map "${SHARE_DIR_PATH}/arch/${DEVICE}/${PART}/pinmap.csv" \
  --net "$NET" $PCF_OPTS \
  > "${IOPLACE_FILE}"

python3 "${SHARE_DIR_PATH}"/scripts/prjxray_create_place_constraints.py \
  --net "$NET" \
  --arch "${ARCH_DEF}" \
  --blif "$EBLIF" \
  --vpr_grid_map "${SHARE_DIR_PATH}/arch/${DEVICE}/vpr_grid_map.csv" \
  --input "${IOPLACE_FILE}" \
  --db_root "${DATABASE_DIR:=$(prjxray-config)}" \
  --part "$PART" \
  > constraints.place
""")


def pack():
    print("[F4PGA] Running (deprecated) pack")
    extra_args = ['--write_block_usage', 'block_usage.json'] if isQuickLogic else []
    run_bash_cmds(vpr_common_cmds('pack')+f"python3 -m f4pga.wrappers.sh.vpr_run --pack {' '.join(extra_args)}")
    Path('vpr_stdout.log').rename('pack.log')


def place():
    print("[F4PGA] Running (deprecated) place")
    place_cmds = """
if [ -z $NET ]; then echo "Please provide net file name"; exit 1; fi
"""
    if isQuickLogic:
        place_cmds += """
if [ -z $PCF ]; then echo "Please provide pcf file name"; exit 1; fi
PROJECT=$(basename -- "$EBLIF")
PROJECT="${PROJECT%.*}"
VPR_PLACE_FILE="${PROJECT}_constraints.place"
if [ -s $PCF ]; then
  echo "Generating constraints ..."
  symbiflow_generate_constraints $PCF $EBLIF $NET $PART $DEVICE $ARCH_DEF $CORNER
  if [ ! -f ${VPR_PLACE_FILE} ]; then VPR_PLACE_FILE="${PROJECT}_io.place"; fi
else
  # Make a dummy empty constraint file
  touch ${VPR_PLACE_FILE}
fi
"""
    else:
        place_cmds += """
PCF=${PCF:=}
echo "Generating constrains ..."
symbiflow_generate_constraints $EBLIF $NET $PART $DEVICE $ARCH_DEF $PCF
VPR_PLACE_FILE='constraints.place'
"""
    place_cmds += 'python3 -m f4pga.wrappers.sh.vpr_run --fix_clusters "${VPR_PLACE_FILE}" --place'
    run_bash_cmds(vpr_common_cmds('place')+place_cmds)
    Path('vpr_stdout.log').rename('place.log')


def route():
    print("[F4PGA] Running (deprecated) route")
    extra_args = ['--write_timing_summary', 'timing_summary.json'] if isQuickLogic else []
    run_bash_cmds(vpr_common_cmds('pack')+f"python3 -m f4pga.wrappers.sh.vpr_run --route {' '.join(extra_args)}")
    Path('vpr_stdout.log').rename('route.log')


def synth():
    print("[F4PGA] Running (deprecated) synth")
    run_sh_script(ROOT / SH_SUBDIR / "synth.f4pga.sh")


def write_fasm(genfasm_extra_args = None):
    print("[F4PGA] Running (deprecated) write fasm")
    run_bash_cmds(vpr_common_cmds('fasm')+"""
TOP="${EBLIF%.*}"
FASM_EXTRA="${TOP}_fasm_extra.fasm"
""" + f"""
'{which('genfasm')}' \
  ${{ARCH_DEF}} ${{EBLIF}} --device ${{DEVICE_NAME}} \
  ${{VPR_OPTIONS}} \
  --read_rr_graph ${{RR_GRAPH}} {' '.join(genfasm_extra_args) if genfasm_extra_args is not None else ''}
""" + """
echo "FASM extra: $FASM_EXTRA"
if [ -f $FASM_EXTRA ]; then
  echo "writing final fasm"
  cat ${TOP}.fasm $FASM_EXTRA > tmp.fasm
  mv tmp.fasm ${TOP}.fasm
fi
""")
    Path('vpr_stdout.log').rename('fasm.log')


def vpr_common():
    print("[F4PGA] Running (deprecated) vpr common")
    run_sh_script(ROOT / SH_SUBDIR / "vpr_common.f4pga.sh")


def vpr_run():
    print("[F4PGA] Running (deprecated) vpr run")
    run_bash_cmds(f"""
  set -e
  SDC_OPTIONS=""
  if [ ! -z $SDC ]; then SDC_OPTIONS="--sdc_file $SDC"; fi
  '{which('vpr')}' "$ARCH_DEF" "$EBLIF" \
    --device "$DEVICE_NAME" \
    $VPR_OPTIONS \
    --read_rr_graph "$RR_GRAPH" \
    --read_router_lookahead "$LOOKAHEAD" \
    --read_placement_delay_lookup "$PLACE_DELAY" \
    $SDC_OPTIONS \
""" + f"{' '.join(sys_argv[1:])}")


# Xilinx only

def write_bitstream():
    print("[F4PGA] Running (deprecated) write bitstream")
    run_bash_cmds("""
set -e
echo "Writing bitstream ..."
FRM2BIT=""
if [ ! -z ${FRAMES2BIT} ]; then FRM2BIT="--frm2bit ${FRAMES2BIT}"; fi
""" + f"""
eval set -- $(
  getopt \
    --options=d:f:b:p: \
    --longoptions=device:,fasm:,bit:,part: \
    --name $0 -- {' '.join(sys_argv[1:])}
)
""" + """
DEVICE=""
FASM=""
BIT=""
PART=xc7a35tcpg236-1
while true; do
  case "$1" in
    -d|--device) DEVICE=$2; shift 2; ;;
    -p|--part)   PART=$2;   shift 2; ;;
    -f|--fasm)   FASM=$2;   shift 2; ;;
    -b|--bit)    BIT=$2;    shift 2; ;;
    --) break ;;
  esac
done
DATABASE_DIR=${DATABASE_DIR:=$(prjxray-config)}
if [ -z $DEVICE ]; then
  # Try to find device name. Accept only when exactly one is found
  PART_DIRS=(${DATABASE_DIR}/*/${PART})
  if [ ${#PART_DIRS[@]} -eq 1 ]; then
    DEVICE=$(basename $(dirname "${PART_DIRS[0]}"))
  else
    echo "Please provide device name"
    exit 1
  fi
fi
DBROOT=`realpath ${DATABASE_DIR}/${DEVICE}`
if [ -z $FASM ]; then echo "Please provide fasm file name"; exit 1; fi
if [ -z $BIT ]; then echo "Please provide bit file name"; exit 1; fi
xcfasm \
  --db-root ${DBROOT} \
  --part ${PART} \
  --part_file ${DBROOT}/${PART}/part.yaml \
  --sparse \
  --emit_pudc_b_pullup \
  --fn_in ${FASM} \
  --bit_out ${BIT} ${FRM2BIT}
""")


# QuickLogic only

def analysis():
    print("[F4PGA] Running (deprecated) analysis")
    run_bash_cmds(vpr_common_cmds('analysis')+"""
python3 -m f4pga.wrappers.sh.vpr_run \
  --analysis \
  --gen_post_synthesis_netlist on \
  --gen_post_implementation_merged_netlist on \
  --post_synth_netlist_unconn_inputs nets \
  --post_synth_netlist_unconn_outputs nets \
  --verify_file_digests off
""")
    Path('vpr_stdout.log').rename('analysis.log')


def repack():
    print("[F4PGA] Running (deprecated) repack")
    run_bash_cmds(vpr_common_cmds()+"""
DESIGN=${EBLIF/.eblif/}
[ ! -z "${JSON}" ] && JSON_ARGS="--json-constraints ${JSON}" || JSON_ARGS=
[ ! -z "${PCF_PATH}" ] && PCF_ARGS="--pcf-constraints ${PCF_PATH}" || PCF_ARGS=
""" + f"""
PYTHONPATH=$F4PGA_SHARE_DIR/scripts:$PYTHONPATH \
  '{which('python3')}' "$F4PGA_SHARE_DIR"/scripts/repacker/repack.py \
    --vpr-arch ${{ARCH_DEF}} \
    --repacking-rules ${{ARCH_DIR}}/${{DEVICE_1}}.repacking_rules.json \
    $JSON_ARGS \
    $PCF_ARGS \
    --eblif-in ${{DESIGN}}.eblif \
    --net-in ${{DESIGN}}.net \
    --place-in ${{DESIGN}}.place \
    --eblif-out ${{DESIGN}}.repacked.eblif \
    --net-out ${{DESIGN}}.repacked.net \
    --place-out ${{DESIGN}}.repacked.place \
    --absorb_buffer_luts on \
    > repack.log 2>&1
""")


def generate_bitstream():
    print("[F4PGA] Running (deprecated) generate_bitstream")
    run_bash_cmds(f"""
set -e
eval set -- "$(
  getopt \
    --options=d:f:r:b:P: \
    --longoptions=device:,fasm:,format:,bit:,part: \
    --name $0 -- {' '.join(sys_argv[1:])}
)"
""" + """
DEVICE=""
FASM=""
BIT_FORMAT="4byte"
BIT=""
PART=""
while true; do
  case "$1" in
    -d|--device) DEVICE=$2;     shift 2;;
    -f|--fasm)   FASM=$2;       shift 2;;
    -r|--format) BIT_FORMAT=$2; shift 2;;
    -b|--bit)    BIT=$2;        shift 2;;
    -P|--part)   PART=$2;       shift 2;;
    --) break;;
  esac
done
if [ -z $DEVICE ]; then echo "Please provide device name"; exit 1; fi
if [ -z $FASM ]; then echo "Please provide an input FASM file name"; exit 1; fi
if [ -z $BIT ]; then echo "Please provide an output bistream file name"; exit 1; fi
""" + f"""
if [[ "$DEVICE" =~ ^(qlf_k4n8.*)$ ]]; then
  '{which('qlf_fasm')}' \
    --db-root "${{SHARE_DIR_PATH:="$F4PGA_SHARE_DIR"}}/fasm_database/${{DEVICE}}" \
    --format "$BIT_FORMAT" \
    --assemble \
    "$FASM" \
    "$BIT"
elif [[ "$DEVICE" =~ ^(ql-eos-s3|ql-pp3e)$ ]]; then
  qlfasm \
    --dev-type \
    "$DEVICE" \
    "$FASM" \
    "$BIT"
else
  echo "ERROR: Unsupported device '${{DEVICE}}' for bitstream generation"
  exit -1
fi
""")


def generate_libfile():
    print("[F4PGA] Running (deprecated) generate_libfile")
    (part, device, corner) = sys_argv[1:4]
    run_bash_cmds(f"""
set -e
if [[ '{device}' =~ ^(qlf_k4n8_qlf_k4n8)$ ]];then
  DEVICE_1="qlf_k4n8-qlf_k4n8_umc22_{corner}"
  PINMAPXML="pinmap_qlf_k4n8_umc22.xml"
  INTERFACEXML="interface-mapping_24x24.xml"
  DEV="qlf_k4n8_umc22"
else
  DEVICE_1={device}
fi
""" + """
ARCH_DIR="$F4PGA_SHARE_DIR"/arch/${DEVICE_1}_${DEVICE_1}
PINMAP_XML=${ARCH_DIR}/${PINMAPXML}
""" + f"""
'{which('python3')}' "$F4PGA_SHARE_DIR"/scripts/create_lib.py \
  -n "${{DEV}}_0P72_SSM40" \
  -m fpga_top \
  -c '{part}' \
  -x "${{ARCH_DIR}}/lib/${{INTERFACEXML}}" \
  -l "${{DEV}}_0P72_SSM40.lib" \
  -t "${{ARCH_DIR}}/lib"
""")


def ql():
    print("[F4PGA] Running (deprecated) ql")
    run_sh_script(ROOT / "quicklogic/ql.f4pga.sh")


def fasm2bels():
    print("[F4PGA] Running (deprecated) fasm2bels")
    run_bash_cmds("""
set -e
SHARE_DIR_PATH=${{SHARE_DIR_PATH:="$F4PGA_SHARE_DIR"}}
""" + f"""
eval set -- "$(
  getopt \
    --options=d:P:p:b:v:o:q \
    --longoptions=device:,part:,pcf:,bit:,out-verilog:,out-pcf:,out-qcf:, \
    --name $0 -- {' '.join(sys_argv[1:])}
)"
""" + """
DEVICE=""
PART=""
PCF=""
BIT=""
OUT_VERILOG=""
OUT_PCF=""
OUT_QCF=""
while true; do
  case "$1" in
    -d|--device)      DEVICE=$2; shift 2 ;;
    -P|--part)        PART=$2;   shift 2 ;;
    -p|--pcf)         PCF=$2;    shift 2 ;;
    -b|--bit)         BIT=$2;    shift 2 ;;
    -v|--out-verilog) OUT_VERILOG=$2; shift 2 ;;
    -o|--out-pcf)     OUT_PCF=$2;     shift 2 ;;
    -q|--out-qcf)     OUT_QCF=$2;     shift 2 ;;
    --) break ;;
  esac
done
if [ -z $DEVICE ]; then echo "Please provide device name"; exit 1; fi
if [ -z $BIT ]; then echo "Please provide an input bistream file name"; exit 1; fi
# $DEVICE is not ql-eos-s3 or ql-pp3e
if ! [[ "$DEVICE" =~ ^(ql-eos-s3|ql-pp3e)$ ]]; then echo "ERROR: Unsupported device '${DEVICE}' for fasm2bels"; exit -1; fi
if [ -z "{PCF}" ]; then PCF_ARGS=""; else PCF_ARGS="--input-pcf ${PCF}"; fi
echo "Running fasm2bels"
""" + f"""
'{which('python3')}' "`readlink -f ${{SHARE_DIR_PATH}}/scripts/fasm2bels.py`" "${{BIT}}" \
  --phy-db "`readlink -f ${{SHARE_DIR_PATH}}/arch/${{DEVICE}}_wlcsp/db_phy.pickle`" \
  --device-name "${{DEVICE/ql-/}}" \
  --package-name "$PART" \
  --input-type bitstream \
  --output-verilog "${{OUT_VERILOG:-$BIT.v}}" \
  ${{PCF_ARGS}} \
  --output-pcf "${{OUT_PCF:-$BIT.v.pcf}}" \
  --output-qcf "${{OUT_QCF:-$BIT.v.qcf}}"
""")


def write_bitheader():
    print("[F4PGA] Running (deprecated) write bitheader")
    print("Converting bitstream to C Header")
    run_pym('quicklogic_fasm.bitstream_to_header')

def write_binary():
    print("[F4PGA] Running (deprecated) write binary")
    print("Converting bitstream to flashable binary format")
    run_pym('quicklogic_fasm.bitstream_to_binary')

def write_jlink():
    print("[F4PGA] Running (deprecated) write jlink")
    print("Converting bitstream to JLink script")
    run_pym('quicklogic_fasm.bitstream_to_jlink')

def write_openocd():
    print("[F4PGA] Running (deprecated) write openocd")
    print("Converting bitstream to OpenOCD script")
    run_pym('quicklogic_fasm.bitstream_to_openocd')
