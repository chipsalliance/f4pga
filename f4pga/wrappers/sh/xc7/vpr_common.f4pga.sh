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

eval set -- "$(
  getopt \
    --options=d:e:p:n:P:s: \
    --longoptions=device:,eblif:,pcf:,net:,part:,sdc: \
    --name $0 -- "$@"
)"
DEVICE=''
DEVICE_NAME=''
PART=''
EBLIF=''
PCF=''
NET=''
SDC=''
ADDITIONAL_VPR_OPTIONS=''
while true; do
  case "$1" in
    -d|--device) DEVICE=$2; shift 2 ;;
    -e|--eblif)  EBLIF=$2;  shift 2 ;;
    -p|--pcf)    PCF=$2;    shift 2 ;;
    -n|--net)    NET=$2;    shift 2 ;;
    -P|--part)   PART=$2;   shift 2 ;;
    -s|--sdc)    SDC=$2;    shift 2 ;;
    --) shift; ADDITIONAL_VPR_OPTIONS="$@"; break ;;
  esac
done

if [ -z "$DEVICE" ] && [ -n "$PART" ]; then
  # Try to find device name. Accept only when exactly one is found
  PART_DIRS=(${F4PGA_SHARE_DIR}/arch/*/${PART})
  if [ ${#PART_DIRS[@]} -eq 1 ]; then DEVICE=$(basename $(dirname "${PART_DIRS[0]}")); fi
fi
if [ -z "$DEVICE" ]; then echo "Please provide device name"; exit 1; fi
if [ -z "$EBLIF" ]; then echo "Please provide blif file name"; exit 1; fi

export DEVICE="$DEVICE"
export EBLIF="$EBLIF"
export PCF="$PCF"
export NET="$NET"
export SDC="$SDC"

if [ -z "$VPR_OPTIONS" ]; then
  echo "Using default VPR options."
  VPR_OPTIONS="
    --max_router_iterations 500
    --routing_failure_predictor off
    --router_high_fanout_threshold -1
    --constant_net_method route
    --route_chan_width 500
    --router_heap bucket
    --clock_modeling route
    --place_delta_delay_matrix_calculation_method dijkstra
    --place_delay_model delta
    --router_lookahead extended_map
    --check_route quick
    --strict_checks off
    --allow_dangling_combinational_nodes on
    --disable_errors check_unbuffered_edges:check_route
    --congested_routing_iteration_threshold 0.8
    --incremental_reroute_delay_ripup off
    --base_cost_type delay_normalized_length_bounded
    --bb_factor 10
    --acc_fac 0.7
    --astar_fac 1.8
    --initial_pres_fac 2.828
    --pres_fac_mult 1.2
    --check_rr_graph off
    --suppress_warnings ${OUT_NOISY_WARNINGS},sum_pin_class:check_unbuffered_edges:load_rr_indexed_data_T_values:check_rr_node:trans_per_R:check_route:set_rr_graph_tool_comment:calculate_average_switch
  "
fi

export VPR_OPTIONS="$VPR_OPTIONS $ADDITIONAL_VPR_OPTIONS"

export ARCH_DIR="${F4PGA_SHARE_DIR}/arch/$DEVICE"
export ARCH_DEF="${ARCH_DIR}"/arch.timing.xml
ARCH_RR_PREFIX="${ARCH_DIR}/rr_graph_${DEVICE}"
export RR_GRAPH="${ARCH_RR_PREFIX}".rr_graph.real.bin
export RR_GRAPH_XML="${ARCH_RR_PREFIX}".rr_graph.real.xml
export PLACE_DELAY="${ARCH_RR_PREFIX}".place_delay.bin
export LOOKAHEAD="${ARCH_RR_PREFIX}".lookahead.bin
export DEVICE_NAME=`echo "$DEVICE" | sed -n 's/_/-/p'`
