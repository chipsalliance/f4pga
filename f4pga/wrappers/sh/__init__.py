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


python3 = which('python3')

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


def p_run_sh_script(script):
    stdout.flush()
    stderr.flush()
    check_call([str(script)]+sys_argv[1:], env=f4pga_environ)


def p_run_bash_cmds(cmds):
    stdout.flush()
    stderr.flush()
    check_call(cmds, env=f4pga_environ, shell=True, executable='/bin/bash')


def p_run_pym(module):
    stdout.flush()
    stderr.flush()
    check_call([python3, '-m' , module]+sys_argv[1:], env=f4pga_environ)


def p_vpr_common_cmds(log_suffix = None):
    return f"""
set -e
source {ROOT / SH_SUBDIR}/vpr_common.f4pga.sh
parse_args {' '.join(sys_argv[1:])}
""" + (f"""
export OUT_NOISY_WARNINGS=noisy_warnings-${{DEVICE}}_{log_suffix}.log
""" if log_suffix is not None else '')


def p_args_str2list(args):
    return [arg for arg in args.strip().split() if arg != '']


def p_vpr_run():
    print("[F4PGA] Running (deprecated) vpr run")

    arg_arch_def = f4pga_environ.get('ARCH_DEF')
    if arg_arch_def is None:
        raise(Exception('[F4PGA] vpr run: envvar ARCH_DEF cannot be unset/empty!'))

    arg_eblif = f4pga_environ.get('EBLIF')
    if arg_eblif is None:
        raise(Exception('[F4PGA] vpr run: envvar EBLIF cannot be unset/empty!'))

    arg_vpr_options = f4pga_environ.get('VPR_OPTIONS')
    if arg_vpr_options is None:
        raise(Exception('[F4PGA] vpr run: envvar VPR_OPTIONS cannot be unset/empty!'))

    arg_device_name = f4pga_environ.get('DEVICE_NAME')
    if arg_device_name is None:
        raise(Exception('[F4PGA] vpr run: envvar DEVICE_NAME cannot be unset/empty!'))

    arg_rr_graph = f4pga_environ.get('RR_GRAPH')
    if arg_rr_graph is None:
        raise(Exception('[F4PGA] vpr run: envvar RR_GRAPH cannot be unset/empty!'))

    arg_lookahead = f4pga_environ.get('LOOKAHEAD')
    if arg_lookahead is None:
        raise(Exception('[F4PGA] vpr run: envvar LOOKAHEAD cannot be unset/empty!'))

    arg_place_delay = f4pga_environ.get('PLACE_DELAY')
    if arg_place_delay is None:
        raise(Exception('[F4PGA] vpr run: envvar PLACE_DELAY cannot be unset/empty!'))

    sdc = f4pga_environ.get('SDC')

    check_call(
        [
            which('vpr'),
            arg_arch_def,
            arg_eblif
        ] + p_args_str2list(arg_vpr_options) + [
            '--device',
            arg_device_name,
            '--read_rr_graph',
            arg_rr_graph,
            '--read_router_lookahead',
            arg_lookahead,
            '--read_placement_delay_lookup',
            arg_place_delay
        ] + (
            ['--sdc_file', sdc] if sdc is not None else []
        ) + sys_argv[1:],
        env=f4pga_environ
    )


# Entrypoints


def generate_constraints():
    print("[F4PGA] Running (deprecated) generate constraints")
    if isQuickLogic:
        (pcf, eblif, net, part, device, arch_def, corner) = sys_argv[1:8]
        place_file_prefix = Path(eblif).stem
        share_dir = Path(f4pga_environ['F4PGA_SHARE_DIR'])
        scripts_dir = share_dir / 'scripts'
        archs_dir = share_dir / 'arch'
        p_run_bash_cmds(f"""
set -e

if [[ '{device}' =~ ^(qlf_.*)$ ]]; then

  if [[ '{device}' =~ ^(qlf_k4n8_qlf_k4n8)$ ]];then
    DEVICE_PATH='qlf_k4n8-qlf_k4n8_umc22_{corner}'
    PINMAPXML="pinmap_qlf_k4n8_umc22.xml"
  elif [[ '{device}' =~ ^(qlf_k6n10_qlf_k6n10)$ ]];then
    DEVICE_PATH="qlf_k6n10-qlf_k6n10_gf12"
    PINMAPXML="pinmap_qlf_k6n10_gf12.xml"
  else
    echo "ERROR: Unknown qlf device '{device}'"
    exit -1
  fi

  '{python3}' '{scripts_dir}/qlf_k4n8_create_ioplace.py' \
    --pcf '{pcf}' \
    --blif '{eblif}' \
    --pinmap_xml '{archs_dir}'/"${{DEVICE_PATH}}_${{DEVICE_PATH}}/${{PINMAPXML}}" \
    --csv_file '{part}' \
    --net '{net}' \
    > '{place_file_prefix}_io.place'

elif [[ '{device}' =~ ^(ql-.*)$ ]]; then

  if ! [[ '{part}' =~ ^(PU64|WR42|PD64|WD30)$ ]]; then
    PINMAPCSV="pinmap_PD64.csv"
    CLKMAPCSV="clkmap_PD64.csv"
  else
    PINMAPCSV='pinmap_{part}.csv'
    CLKMAPCSV='clkmap_{part}.csv'
  fi

  echo "PINMAP FILE : $PINMAPCSV"
  echo "CLKMAP FILE : $CLKMAPCSV"

  DEVICE_PATH='{device}_wlcsp'
  PINMAP='{archs_dir}'/"${{DEVICE_PATH}}/${{PINMAPCSV}}"

  '{python3}' '{scripts_dir}/pp3_create_ioplace.py' \
    --pcf '{pcf}' \
    --blif '{eblif}' \
    --map "$PINMAP" \
    --net '{net}' \
    > '{place_file_prefix}_io.place'

  '{python3}' '{scripts_dir}/pp3_create_place_constraints.py' \
    --blif '{eblif}' \
    --map '{archs_dir}'/"${{DEVICE_PATH}}/${{CLKMAPCSV}}" \
    -i '{place_file_prefix}_io.place' \
    > '{place_file_prefix}_constraints.place'

  # EOS-S3 IOMUX configuration
  if [[ '{device}' =~ ^(ql-eos-s3)$ ]]; then
""" + '\n'.join([f"""
    '{python3}' '{scripts_dir}/pp3_eos_s3_iomux_config.py' \
      --eblif '{eblif}' \
      --pcf '{pcf}' \
      --map "$PINMAP" \
      --output-format={fmt[0]} \
      > '{place_file_prefix}_iomux.{fmt[1]}'
""" for fmt in [['jlink', 'jlink'], ['openocd', 'openocd'], ['binary', 'bin']]]) + f"""
  fi

else
  echo "FIXME: Unsupported device '{device}'"
  exit -1
fi
""")
    else:
        (eblif, net, part, device, arch_def) = sys_argv[1:6]
        pcf_opts = f"'--pcf' '{sys_argv[6]}'" if len(sys_argv) > 6 else ''
        ioplace_file = f'{Path(eblif).stem}.ioplace'
        share_dir = f4pga_environ['F4PGA_SHARE_DIR']
        p_run_bash_cmds(f"""
set -e
python3 '{share_dir}/scripts/prjxray_create_ioplace.py' \
  --blif '{eblif}' \
  --net '{net}' {pcf_opts} \
  --map '{share_dir}/arch/{device}/{part}/pinmap.csv' \
  > '{ioplace_file}'
python3 '{share_dir}'/scripts/prjxray_create_place_constraints.py \
  --blif '{eblif}' \
  --net '{net}' \
  --arch '{arch_def}' \
  --part '{part}' \
  --vpr_grid_map '{share_dir}/arch/{device}/vpr_grid_map.csv' \
  --input '{ioplace_file}' \
  --db_root "${{DATABASE_DIR:-$(prjxray-config)}}" \
  > constraints.place
""")


def pack():
    print("[F4PGA] Running (deprecated) pack")
    extra_args = ['--write_block_usage', 'block_usage.json'] if isQuickLogic else []
    p_run_bash_cmds(p_vpr_common_cmds('pack')+f"python3 -m f4pga.wrappers.sh.vpr_run --pack {' '.join(extra_args)}")
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
  python3 -m f4pga.wrappers.sh.generate_constraints $PCF $EBLIF $NET $PART $DEVICE $ARCH_DEF $CORNER
  if [ ! -f ${VPR_PLACE_FILE} ]; then VPR_PLACE_FILE="${PROJECT}_io.place"; fi
else
  # Make a dummy empty constraint file
  touch ${VPR_PLACE_FILE}
fi
"""
    else:
        place_cmds += """
echo "Generating constrains ..."
python3 -m f4pga.wrappers.sh.generate_constraints $EBLIF $NET $PART $DEVICE $ARCH_DEF $PCF
VPR_PLACE_FILE='constraints.place'
"""
    place_cmds += 'python3 -m f4pga.wrappers.sh.vpr_run --fix_clusters "${VPR_PLACE_FILE}" --place'
    p_run_bash_cmds(p_vpr_common_cmds('place')+place_cmds)
    Path('vpr_stdout.log').rename('place.log')


def route():
    print("[F4PGA] Running (deprecated) route")
    extra_args = ['--write_timing_summary', 'timing_summary.json'] if isQuickLogic else []
    p_run_bash_cmds(p_vpr_common_cmds('pack')+f"python3 -m f4pga.wrappers.sh.vpr_run --route {' '.join(extra_args)}")
    Path('vpr_stdout.log').rename('route.log')


def synth():
    print("[F4PGA] Running (deprecated) synth")
    p_run_sh_script(ROOT / SH_SUBDIR / "synth.f4pga.sh")


def write_fasm(genfasm_extra_args = None):
    print("[F4PGA] Running (deprecated) write fasm")
    p_run_bash_cmds(p_vpr_common_cmds('fasm')+f"""
'{which('genfasm')}' \
  ${{ARCH_DEF}} ${{EBLIF}} --device ${{DEVICE_NAME}} \
  ${{VPR_OPTIONS}} \
  --read_rr_graph ${{RR_GRAPH}} {' '.join(genfasm_extra_args) if genfasm_extra_args is not None else ''}
""" + """
TOP="${EBLIF%.*}"
FASM_EXTRA="${TOP}_fasm_extra.fasm"
if [ -f $FASM_EXTRA ]; then
  echo "writing final fasm (extra: $FASM_EXTRA)"
  cat $FASM_EXTRA >> ${TOP}.fasm
fi
""")
    Path('vpr_stdout.log').rename('fasm.log')


# Xilinx only


def write_bitstream():
    print("[F4PGA] Running (deprecated) write bitstream")
    p_run_bash_cmds("""
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
DATABASE_DIR=${DATABASE_DIR:-$(prjxray-config)}
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
    p_run_bash_cmds(p_vpr_common_cmds('analysis')+"""
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
    p_run_bash_cmds(p_vpr_common_cmds()+"""
DESIGN=${EBLIF/.eblif/}
[ ! -z "${JSON}" ] && JSON_ARGS="--json-constraints ${JSON}" || JSON_ARGS=
[ ! -z "${PCF_PATH}" ] && PCF_ARGS="--pcf-constraints ${PCF_PATH}" || PCF_ARGS=
""" + f"""
PYTHONPATH=$F4PGA_SHARE_DIR/scripts:$PYTHONPATH \
  '{python3}' "$F4PGA_SHARE_DIR"/scripts/repacker/repack.py \
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
    p_run_bash_cmds(f"""
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
    --db-root "${{F4PGA_SHARE_DIR}}/fasm_database/${{DEVICE}}" \
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
    p_run_bash_cmds(f"""
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
ARCH_DIR="${F4PGA_SHARE_DIR}/arch/${DEVICE_1}_${DEVICE_1}"
PINMAP_XML=${ARCH_DIR}/${PINMAPXML}
""" + f"""
'{python3}' "$F4PGA_SHARE_DIR"/scripts/create_lib.py \
  -n "${{DEV}}_0P72_SSM40" \
  -m fpga_top \
  -c '{part}' \
  -x "${{ARCH_DIR}}/lib/${{INTERFACEXML}}" \
  -l "${{DEV}}_0P72_SSM40.lib" \
  -t "${{ARCH_DIR}}/lib"
""")


def ql():
    print("[F4PGA] Running (deprecated) ql")
    p_run_sh_script(ROOT / "quicklogic/ql.f4pga.sh")


def fasm2bels():
    print("[F4PGA] Running (deprecated) fasm2bels")
    p_run_bash_cmds(f"""
set -e
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
'{python3}' "${{F4PGA_SHARE_DIR}}"/scripts/fasm2bels.py "${{BIT}}" \
  --phy-db "${{F4PGA_SHARE_DIR}}/arch/${{DEVICE}}_wlcsp/db_phy.pickle" \
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
    p_run_pym('quicklogic_fasm.bitstream_to_header')

def write_binary():
    print("[F4PGA] Running (deprecated) write binary")
    print("Converting bitstream to flashable binary format")
    p_run_pym('quicklogic_fasm.bitstream_to_binary')

def write_jlink():
    print("[F4PGA] Running (deprecated) write jlink")
    print("Converting bitstream to JLink script")
    p_run_pym('quicklogic_fasm.bitstream_to_jlink')

def write_openocd():
    print("[F4PGA] Running (deprecated) write openocd")
    print("Converting bitstream to OpenOCD script")
    p_run_pym('quicklogic_fasm.bitstream_to_openocd')
