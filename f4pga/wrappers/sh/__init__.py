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
from argparse import ArgumentParser, RawDescriptionHelpFormatter

from f4pga.context import FPGA_FAM, F4PGA_SHARE_DIR


python3 = which("python3")

ROOT = Path(__file__).resolve().parent

isQuickLogic = FPGA_FAM != "xc7"
SH_SUBDIR = "quicklogic" if isQuickLogic else FPGA_FAM


if not isQuickLogic:
    from f4pga.aux.utils.xc7.create_ioplace import main as xc7_create_ioplace
    from f4pga.aux.utils.xc7.create_place_constraints import main as xc7_create_place_constraints


# Helper functions


def p_run_sh_script(script, env=environ):
    stdout.flush()
    stderr.flush()
    check_call([str(script)] + sys_argv[1:], env=env)


def p_run_bash_cmds(cmds, env=environ):
    stdout.flush()
    stderr.flush()
    check_call(cmds, env=env, shell=True, executable="/bin/bash")


def p_run_pym(module, env=environ):
    stdout.flush()
    stderr.flush()
    check_call([python3, "-m", module] + sys_argv[1:], env=env)


def p_vpr_env_from_args(log_suffix=None):
    vpr_options = environ.get("VPR_OPTIONS")
    if vpr_options is not None:
        vpr_options = p_args_str2list(vpr_options)

    env = environ.copy()
    env.update(
        p_parse_vpr_args(
            vpr_options=vpr_options,
            log_suffix=log_suffix,
            isQuickLogic=isQuickLogic,
        )
    )
    return env


def p_args_str2list(args):
    return [arg for arg in args.strip().split() if arg != ""]


def p_vpr_run(args, env=environ):
    print("[F4PGA] Running (deprecated) vpr run")

    arg_arch_def = env.get("ARCH_DEF")
    if arg_arch_def is None:
        raise (Exception("[F4PGA] vpr run: envvar ARCH_DEF cannot be unset/empty!"))

    arg_eblif = env.get("EBLIF")
    if arg_eblif is None:
        raise (Exception("[F4PGA] vpr run: envvar EBLIF cannot be unset/empty!"))

    arg_vpr_options = env.get("VPR_OPTIONS")
    if arg_vpr_options is None:
        raise (Exception("[F4PGA] vpr run: envvar VPR_OPTIONS cannot be unset/empty!"))

    arg_device_name = env.get("DEVICE_NAME")
    if arg_device_name is None:
        raise (Exception("[F4PGA] vpr run: envvar DEVICE_NAME cannot be unset/empty!"))

    arg_rr_graph = env.get("RR_GRAPH")
    if arg_rr_graph is None:
        raise (Exception("[F4PGA] vpr run: envvar RR_GRAPH cannot be unset/empty!"))

    arg_lookahead = env.get("LOOKAHEAD")
    if arg_lookahead is None:
        raise (Exception("[F4PGA] vpr run: envvar LOOKAHEAD cannot be unset/empty!"))

    arg_place_delay = env.get("PLACE_DELAY")
    if arg_place_delay is None:
        raise (Exception("[F4PGA] vpr run: envvar PLACE_DELAY cannot be unset/empty!"))

    sdc = env.get("SDC")
    if sdc == "":
        sdc = None

    check_call(
        [which("vpr"), arg_arch_def, arg_eblif]
        + p_args_str2list(arg_vpr_options)
        + [
            "--device",
            arg_device_name,
            "--read_rr_graph",
            arg_rr_graph,
            "--read_router_lookahead",
            arg_lookahead,
            "--read_placement_delay_lookup",
            arg_place_delay,
        ]
        + (["--sdc_file", sdc] if sdc is not None else [])
        + args,
    )


def p_parse_vpr_args(vpr_options=None, log_suffix=None, isQuickLogic=False):
    if isQuickLogic:
        return p_parse_vpr_args_quicklogic(vpr_options, log_suffix)
    else:
        return p_parse_vpr_args_xc7(vpr_options, log_suffix)


def p_parse_vpr_args_xc7(vpr_options=None, log_suffix=None):
    parser = ArgumentParser(description=__doc__, formatter_class=RawDescriptionHelpFormatter)
    parser.add_argument("--device", "-d", required=False, type=str, help="")
    parser.add_argument("--eblif", "-e", required=True, type=str, help="")
    parser.add_argument("--pcf", "-p", required=False, type=str, help="")
    parser.add_argument("--net", "-n", required=False, type=str, help="")
    parser.add_argument("--part", "-P", required=False, type=str, help="")
    parser.add_argument("--sdc", "-s", required=False, type=str, help="")
    parser.add_argument("additional_vpr_options", nargs="*", type=str, help="")
    args = parser.parse_args()

    device = args.device
    if device is None and args.part is not None:
        parts_dir = F4PGA_SHARE_DIR
        # Try to find device name.
        # Accept only when exactly one is found.
        # PART_DIRS=(${F4PGA_SHARE_DIR}/arch/*/${PART})
        # if [ ${#PART_DIRS[@]} -eq 1 ]; then DEVICE=$(basename $(dirname "${PART_DIRS[0]}")); fi

    if device is None:
        raise Exception("Please provide device name")

    noisy_warnings = "" if log_suffix is None else f"noisy_warnings-{device}_{log_suffix}.log"

    if vpr_options is None:
        print("Using default VPR options")
        vpr_options = [
            "--max_router_iterations",
            "500",
            "--routing_failure_predictor",
            "off",
            "--router_high_fanout_threshold",
            "-1",
            "--constant_net_method",
            "route",
            "--route_chan_width",
            "500",
            "--router_heap",
            "bucket",
            "--clock_modeling",
            "route",
            "--place_delta_delay_matrix_calculation_method",
            "dijkstra",
            "--place_delay_model",
            "delta",
            "--router_lookahead",
            "extended_map",
            "--check_route",
            "quick",
            "--strict_checks",
            "off",
            "--allow_dangling_combinational_nodes",
            "on",
            "--disable_errors",
            "check_unbuffered_edges:check_route",
            "--congested_routing_iteration_threshold",
            "0.8",
            "--incremental_reroute_delay_ripup",
            "off",
            "--base_cost_type",
            "delay_normalized_length_bounded",
            "--bb_factor",
            "10",
            "--acc_fac",
            "0.7",
            "--astar_fac",
            "1.8",
            "--initial_pres_fac",
            "2.828",
            "--pres_fac_mult",
            "1.2",
            "--check_rr_graph",
            "off",
            "--suppress_warnings",
            noisy_warnings
            + ",sum_pin_class:check_unbuffered_edges:load_rr_indexed_data_T_values:check_rr_node:trans_per_R:check_route:set_rr_graph_tool_comment:calculate_average_switch",
        ]

    arch_dir = F4PGA_SHARE_DIR / "arch" / device

    envvars = {
        "DEVICE": device,
        "DEVICE_NAME": device.replace("_", "-"),
        "EBLIF": args.eblif,
        "VPR_OPTIONS": " ".join(vpr_options + args.additional_vpr_options),
        "ARCH_DIR": str(arch_dir),
        "ARCH_DEF": str(arch_dir / "arch.timing.xml"),
        "RR_GRAPH": str(arch_dir / f"rr_graph_{device}.rr_graph.real.bin"),
        "RR_GRAPH_XML": str(arch_dir / f"rr_graph_{device}.rr_graph.real.xml"),
        "PLACE_DELAY": str(arch_dir / f"rr_graph_{device}.place_delay.bin"),
        "LOOKAHEAD": str(arch_dir / f"rr_graph_{device}.lookahead.bin"),
    }

    if args.pcf is not None:
        envvars["PCF"] = args.pcf
    if args.net is not None:
        envvars["NET"] = args.net
    if args.part is not None:
        envvars["PART"] = args.part
    if args.sdc is not None:
        envvars["SDC"] = args.sdc

    if log_suffix is not None:
        envvars["OUT_NOISY_WARNINGS"] = noisy_warnings

    return envvars


def p_parse_vpr_args_quicklogic(vpr_options=None, log_suffix=None):
    parser = ArgumentParser(description=__doc__, formatter_class=RawDescriptionHelpFormatter)
    parser.add_argument("--device", "-d", required=True, type=str, help="")
    parser.add_argument("--family", "-f", required=True, type=str, help="")
    parser.add_argument("--eblif", "-e", required=True, type=str, help="")
    parser.add_argument("--pcf", "-p", required=False, type=str, help="")
    parser.add_argument("--net", "-n", required=False, type=str, help="")
    parser.add_argument("--part", "-P", required=False, type=str, help="")
    parser.add_argument("--json", "-j", required=False, type=str, help="")
    parser.add_argument("--sdc", "-s", required=False, type=str, help="")
    parser.add_argument("--top", "-t", required=False, type=str, help="")
    parser.add_argument("--corner", "-c", required=False, type=str, help="")
    args = parser.parse_args()

    if vpr_options is None:
        print("Using default VPR options")
        vpr_options = [
            "--max_router_iterations",
            "500",
            "--routing_failure_predictor",
            "off",
            "--router_high_fanout_threshold",
            "-1",
            "--constant_net_method",
            "route",
        ]

    noisy_warnings = "" if log_suffix is None else f"noisy_warnings-{args.device}_{log_suffix}.log"

    vpr_options.extend(
        [
            "--place_delay_model",
            "delta_override",
            "--router_lookahead",
            "extended_map",
            "--allow_dangling_combinational_nodes",
            "on",
        ]
        + (
            [
                "--route_chan_width",
                "10",
                "--clock_modeling",
                "ideal",
                "--place_delta_delay_matrix_calculation_method",
                "dijkstra",
                "--absorb_buffer_luts",
                "off",
            ]
            if args.device == "qlf_k4n8_qlf_k4n8"
            else [
                "--route_chan_width",
                "100",
                "--clock_modeling",
                "route",
                "--check_route",
                "quick",
                "--strict_checks",
                "off",
                "--disable_errors",
                "check_unbuffered_edges:check_route",
                "--congested_routing_iteration_threshold",
                "0.8",
                "--incremental_reroute_delay_ripup",
                "off",
                "--base_cost_type",
                "delay_normalized_length_bounded",
                "--bb_factor",
                "10",
                "--initial_pres_fac",
                "4.0",
                "--check_rr_graph",
                "off",
                "--pack_high_fanout_threshold",
                "PB-LOGIC:18",
                "--suppress_warnings",
                noisy_warnings
                + ",sum_pin_class:check_unbuffered_edges:load_rr_indexed_data_T_values:check_rr_node:trans_per_R:check_route:set_rr_graph_tool_comment",
            ]
        )
    )

    device_2 = None
    if args.device == "qlf_k4n8_qlf_k4n8":
        device_1 = f"qlf_k4n8-qlf_k4n8_umc22_{args.corner}"
    elif args.device == "qlf_k6n10_qlf_k6n10":
        device_1 = "qlf_k6n10-qlf_k6n10_gf12"
    else:
        device_1 = args.device
        device_2 = "wlcsp"
    if device_2 is None:
        device_2 = device_1

    device_arch = f"{device_1}_{device_2}"
    arch_dir = F4PGA_SHARE_DIR / "arch" / device_arch

    rr_graph = arch_dir / f"{device_1}.rr_graph.bin"
    # qlf* devices use different naming scheme than pp3* ones.
    if not rr_graph.exists():
        rr_graph = arch_dir / f"rr_graph_{device_arch}.rr_graph.real.bin"

    envvars = {
        "DEVICE": args.device,
        "FAMILY": args.family,
        "EBLIF": args.eblif,
        "VPR_OPTIONS": " ".join(vpr_options),
        "ARCH_DIR": str(arch_dir),
        "ARCH_DEF": str(arch_dir / f"arch_{device_arch}.xml"),
        "RR_GRAPH": str(rr_graph),
        "PLACE_DELAY": str(arch_dir / f"rr_graph_{device_arch}.place_delay.bin"),
        "LOOKAHEAD": str(arch_dir / f"rr_graph_{device_arch}.lookahead.bin"),
        "DEVICE_NAME": device_1,
    }

    if args.pcf is not None:
        envvars["PCF"] = args.pcf
    if args.net is not None:
        envvars["NET"] = args.net
    if args.json is not None:
        envvars["JSON"] = args.json
    if args.sdc is not None:
        envvars["SDC"] = args.sdc
    if args.top is not None:
        envvars["TOP"] = args.top
    if args.sdc is not None:
        envvars["CORNER"] = args.corner

    if log_suffix is not None:
        envvars["OUT_NOISY_WARNINGS"] = noisy_warnings

    return envvars


# Entrypoints


def generate_constraints():
    print("[F4PGA] Running (deprecated) generate constraints")
    if isQuickLogic:
        (pcf, eblif, net, part, device, arch_def, corner) = sys_argv[1:8]
        place_file_prefix = Path(eblif).stem
        scripts_dir = F4PGA_SHARE_DIR / "scripts"
        archs_dir = F4PGA_SHARE_DIR / "arch"
        p_run_bash_cmds(
            f"""
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

  f4pga utils create_ioplace \
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

  f4pga utils create_ioplace \
    --pcf '{pcf}' \
    --blif '{eblif}' \
    --map "$PINMAP" \
    --net '{net}' \
    > '{place_file_prefix}_io.place'

  f4pga utils create_place_constraints \
    --blif '{eblif}' \
    --map '{archs_dir}'/"${{DEVICE_PATH}}/${{CLKMAPCSV}}" \
    -i '{place_file_prefix}_io.place' \
    > '{place_file_prefix}_constraints.place'

  # EOS-S3 IOMUX configuration
  if [[ '{device}' =~ ^(ql-eos-s3)$ ]]; then
"""
            + "\n".join(
                [
                    f"""
    f4pga utils iomux_config \
      --eblif '{eblif}' \
      --pcf '{pcf}' \
      --map "$PINMAP" \
      --output-format={fmt[0]} \
      > '{place_file_prefix}_iomux.{fmt[1]}'
"""
                    for fmt in [["jlink", "jlink"], ["openocd", "openocd"], ["binary", "bin"]]
                ]
            )
            + f"""
  fi

else
  echo "FIXME: Unsupported device '{device}'"
  exit -1
fi
"""
        )
    else:
        (eblif, net, part, device, arch_def) = sys_argv[1:6]
        ioplace_file = f"{Path(eblif).stem}.ioplace"
        xc7_create_ioplace(
            blif=eblif,
            map=f"{F4PGA_SHARE_DIR}/arch/{device}/{part}/pinmap.csv",
            net=net,
            output=ioplace_file,
            pcf=Path(sys_argv[6]).open("r") if len(sys_argv) > 6 else None,
        )
        xc7_create_place_constraints(
            blif=eblif,
            net=net,
            arch=arch_def,
            part=part,
            vpr_grid_map=f"{F4PGA_SHARE_DIR}/arch/{device}/vpr_grid_map.csv",
            input=ioplace_file,
            output="constraints.place",
        )


def pack():
    print("[F4PGA] Running (deprecated) pack")
    extra_args = ["--write_block_usage", "block_usage.json"] if isQuickLogic else []
    p_vpr_run(["--pack"] + extra_args, env=p_vpr_env_from_args("pack"))
    Path("vpr_stdout.log").rename("pack.log")


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
    p_run_bash_cmds(place_cmds, env=p_vpr_env_from_args("place"))
    Path("vpr_stdout.log").rename("place.log")


def route():
    print("[F4PGA] Running (deprecated) route")
    extra_args = ["--write_timing_summary", "timing_summary.json"] if isQuickLogic else []
    p_vpr_run(["--route"] + extra_args, env=p_vpr_env_from_args("pack"))
    Path("vpr_stdout.log").rename("route.log")


def synth():
    print("[F4PGA] Running (deprecated) synth")
    env = environ.copy()

    if environ.get("F4PGA_SHARE_DIR") is None:
        env["F4PGA_SHARE_DIR"] = str(F4PGA_SHARE_DIR)

    env["UTILS_PATH"] = str(F4PGA_SHARE_DIR / "scripts")

    if isQuickLogic:
        key = None
        for item in ["-F", "--family"]:
            if item in sys_argv:
                key = item
                break
        if key is None:
            raise Exception("Please specify device family")
        family = sys_argv[sys_argv.index(key) + 1]
        env.update(
            {
                "FAMILY": family,
                "TECHMAP_PATH": str(F4PGA_SHARE_DIR / "techmaps" / family),
            }
        )
    else:
        env["TECHMAP_PATH"] = str(F4PGA_SHARE_DIR / "techmaps/xc7_vpr/techmap")

    p_run_sh_script(ROOT / SH_SUBDIR / "synth.f4pga.sh", env=env)


def write_fasm(genfasm_extra_args=None):
    print("[F4PGA] Running (deprecated) write fasm")
    p_run_bash_cmds(
        f"""
'{which('genfasm')}' \
  ${{ARCH_DEF}} ${{EBLIF}} --device ${{DEVICE_NAME}} \
  ${{VPR_OPTIONS}} \
  --read_rr_graph ${{RR_GRAPH}} {' '.join(genfasm_extra_args) if genfasm_extra_args is not None else ''}
"""
        + """
TOP="${EBLIF%.*}"
FASM_EXTRA="${TOP}_fasm_extra.fasm"
if [ -f $FASM_EXTRA ]; then
  echo "writing final fasm (extra: $FASM_EXTRA)"
  cat $FASM_EXTRA >> ${TOP}.fasm
fi
""",
        env=p_vpr_env_from_args("fasm"),
    )
    Path("vpr_stdout.log").rename("fasm.log")


# Xilinx only


def write_bitstream():
    print("[F4PGA] Running (deprecated) write bitstream")
    p_run_bash_cmds(
        """
set -e
echo "Writing bitstream ..."
FRM2BIT=""
if [ ! -z ${FRAMES2BIT} ]; then FRM2BIT="--frm2bit ${FRAMES2BIT}"; fi
"""
        + f"""
eval set -- $(
  getopt \
    --options=d:f:b:p: \
    --longoptions=device:,fasm:,bit:,part: \
    --name $0 -- {' '.join(sys_argv[1:])}
)
"""
        + """
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
"""
    )


# QuickLogic only


def analysis():
    print("[F4PGA] Running (deprecated) analysis")
    p_vpr_run(
        [
            "--analysis",
            "--gen_post_synthesis_netlist",
            "on",
            "--gen_post_implementation_merged_netlist",
            "on",
            "--post_synth_netlist_unconn_inputs",
            "nets",
            "--post_synth_netlist_unconn_outputs",
            "nets",
            "--verify_file_digests",
            "off",
        ],
        env=p_vpr_env_from_args("analysis"),
    )
    Path("vpr_stdout.log").rename("analysis.log")


def repack():
    print("[F4PGA] Running (deprecated) repack")
    p_run_bash_cmds(
        """
DESIGN=${EBLIF/.eblif/}
[ ! -z "${JSON}" ] && JSON_ARGS="--json-constraints ${JSON}" || JSON_ARGS=
[ ! -z "${PCF_PATH}" ] && PCF_ARGS="--pcf-constraints ${PCF_PATH}" || PCF_ARGS=
"""
        + f"""
PYTHONPATH='{F4PGA_SHARE_DIR}/scripts':$PYTHONPATH \
  f4pga utils repack \
    --vpr-arch ${{ARCH_DEF}} \
    --repacking-rules ${{ARCH_DIR}}/${{DEVICE_NAME}}.repacking_rules.json \
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
""",
        env=p_vpr_env_from_args(),
    )


def generate_bitstream():
    print("[F4PGA] Running (deprecated) generate_bitstream")
    parser = ArgumentParser(description=__doc__, formatter_class=RawDescriptionHelpFormatter)
    parser.add_argument("--device", "-d", required=True, type=str, help="")
    parser.add_argument("--fasm", "-f", required=True, type=str, help="")
    parser.add_argument("--bit", "-b", required=True, type=str, help="")
    parser.add_argument("--format", "-r", required=False, type=str, help="")
    args = parser.parse_args()

    if not Path(args.fasm).exists():
        raise Exception(f"File <{args.fasm}> does not exist!")

    fmt = "4byte" if args.format is None else args.format
    db_root = F4PGA_SHARE_DIR / "fasm_database" / args.device

    if "qlf_k4n8" in args.device:
        p_run_bash_cmds(
            f"'{which('qlf_fasm')}' --db-root '{db_root}' --format '{fmt}' --assemble '{args.fasm}' '{args.bit}'"
        )
    elif args.device in ["ql-eos-s3", "ql-pp3e"]:
        p_run_bash_cmds(f"qlfasm --dev-type '{args.device}' '{args.fasm}' '{args.bit}'")
    else:
        raise Exception(f"[bitstream generation] Unsupported device '{args.device}'!")


def generate_libfile():
    print("[F4PGA] Running (deprecated) generate_libfile")
    (part, device, corner) = sys_argv[1:4]
    p_run_bash_cmds(
        f"""
set -e
if [[ '{device}' =~ ^(qlf_k4n8_qlf_k4n8)$ ]];then
  DEVICE_1="qlf_k4n8-qlf_k4n8_umc22_{corner}"
  PINMAPXML="pinmap_qlf_k4n8_umc22.xml"
  INTERFACEXML="interface-mapping_24x24.xml"
  DEV="qlf_k4n8_umc22"
else
  DEVICE_1={device}
fi
ARCH_DIR='{F4PGA_SHARE_DIR}/arch/'"${{DEVICE_1}}_${{DEVICE_1}}"
"""
        + """
PINMAP_XML=${ARCH_DIR}/${PINMAPXML}
"""
        + f"""
f4pga utils create_lib \
  -n "${{DEV}}_0P72_SSM40" \
  -m fpga_top \
  -c '{part}' \
  -x "${{ARCH_DIR}}/lib/${{INTERFACEXML}}" \
  -l "${{DEV}}_0P72_SSM40.lib" \
  -t "${{ARCH_DIR}}/lib"
"""
    )


def ql():
    print("[F4PGA] Running (deprecated) ql")
    env = environ.copy()
    if environ.get("F4PGA_SHARE_DIR") is None:
        env["F4PGA_SHARE_DIR"] = str(F4PGA_SHARE_DIR)
    p_run_sh_script(ROOT / "quicklogic/ql.f4pga.sh", env=env)


def fasm2bels():
    print("[F4PGA] Running (deprecated) fasm2bels")
    parser = ArgumentParser(description=__doc__, formatter_class=RawDescriptionHelpFormatter)
    parser.add_argument("--device", "-d", required=True, type=str, help="")
    parser.add_argument("--bit", "-b", required=True, type=str, help="")
    parser.add_argument("--part", "-P", required=True, type=str, help="")
    parser.add_argument("--pcf", "-p", required=False, type=str, help="")
    parser.add_argument("--out-verilog", "-v", required=False, type=str, help="")
    parser.add_argument("--out-pcf", "-o", required=False, type=str, help="")
    parser.add_argument("--out-qcf", "-q", required=False, type=str, help="")
    args = parser.parse_args()

    if args.device not in ["ql-eos-s3", "ql-pp3e"]:
        raise Exception(f"[fasm2bels] Unsupported device '{args.device}'")

    env = environ.copy()
    env["DEVICE"] = args.device

    pcf_args = "" if args.pcf is None else f"--input-pcf {args.pcf}"
    out_verilog = f"{args.bit}.v" if args.out_verilog is None else args.out_verilog
    out_pcf = f"{args.bit}.v.pcf" if args.out_pcf is None else args.out_pcf
    out_qcf = f"{args.bit}.v.qcf" if args.out_qcf is None else args.out_qcf

    p_run_bash_cmds(
        f"""
f4pga utils fasm2bels '{args.bit}' \
  --phy-db '{F4PGA_SHARE_DIR}/arch/{args.device}_wlcsp/db_phy.pickle' \
  --device-name "${{DEVICE/ql-/}}" \
  --package-name '{args.part}' \
  --input-type bitstream \
  --output-verilog '{out_verilog}' \
  {pcf_args} \
  --output-pcf '{out_pcf}' \
  --output-qcf '{out_qcf}'
""",
        env=env,
    )


def write_bitheader():
    print("[F4PGA] Running (deprecated) write bitheader")
    print("Converting bitstream to C Header")
    p_run_pym("quicklogic_fasm.bitstream_to_header")


def write_binary():
    print("[F4PGA] Running (deprecated) write binary")
    print("Converting bitstream to flashable binary format")
    p_run_pym("quicklogic_fasm.bitstream_to_binary")


def write_jlink():
    print("[F4PGA] Running (deprecated) write jlink")
    print("Converting bitstream to JLink script")
    p_run_pym("quicklogic_fasm.bitstream_to_jlink")


def write_openocd():
    print("[F4PGA] Running (deprecated) write openocd")
    print("Converting bitstream to OpenOCD script")
    p_run_pym("quicklogic_fasm.bitstream_to_openocd")
