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

SHARE_DIR_PATH=${SHARE_DIR_PATH:="$F4PGA_SHARE_DIR"}

if [ -z $VPR_OPTIONS ]; then
     echo "Using default VPR options."
     VPR_OPTIONS="
       --max_router_iterations 500
       --routing_failure_predictor off
       --router_high_fanout_threshold -1
       --constant_net_method route
       "
fi

function parse_args {

     OPTS=d:f:e:p:n:P:j:s:t:c:
     LONGOPTS=device:,eblif:,pcf:,net:,part:,json:,sdc:,top:,corner:

     PARSED_OPTS=`getopt --options=${OPTS} --longoptions=${LONGOPTS} --name $0 -- $@`
     eval set -- ${PARSED_OPTS}

     DEVICE=""
     FAMILY=""
     DEVICE_NAME=""
     PART=""
     EBLIF=""
     PCF=""
     NET=""
     SDC=""
     JSON=""
     TOP="top"
     CORNER=""

     while true; do
          case "$1" in
               -d|--device)
                    DEVICE=$2
                    shift 2
                    ;;
               -f|--family)
                    FAMILY=$2
                    shift 2
                    ;;
               -e|--eblif)
                    EBLIF=$2
                    shift 2
                    ;;
               -p|--pcf)
                    PCF=$2
                    shift 2
                    ;;
               -n|--net)
                    NET=$2
                    shift 2
                    ;;
               -P|--part)
                    PART=$2
                    shift 2
                    ;;
               -j|--json)
                    JSON=$2
                    shift 2
                    ;;
               -s|--sdc)
                    SDC=$2
                    shift 2
                    ;;
               -t|--top)
                    TOP=$2
                    shift 2
                    ;;
               -c|--corner)
                    CORNER=$2
                    shift 2
                    ;;
               --)
                    break
                    ;;
          esac
     done

     if [ -z $DEVICE ]; then
          echo "Please provide device name"
          exit 1
     fi

     if [ -z $FAMILY ]; then
          echo "Please provide device family name"
          exit 1
     fi

     if [ -z $EBLIF ]; then
          echo "Please provide blif file name"
          exit 1
     fi

     export DEVICE=$DEVICE
     export FAMILY=$FAMILY
     export EBLIF=$EBLIF
     export PCF=$PCF
     export NET=$NET
     export SDC=$SDC
     export JSON=$JSON
     export CORNER=$CORNER
     if [[ "$DEVICE" == "qlf_k4n8_qlf_k4n8" ]]; then
	     DEVICE_1="qlf_k4n8-qlf_k4n8_umc22_${CORNER}"
	     DEVICE_2=${DEVICE_1}
     elif [[ "$DEVICE" == "qlf_k6n10_qlf_k6n10" ]];then
	     DEVICE_1="qlf_k6n10-qlf_k6n10_gf12"
	     DEVICE_2=${DEVICE_1}
     else
	     DEVICE_1=${DEVICE}
	     DEVICE_2="wlcsp"
     fi
     export TOP=$TOP

     export ARCH_DIR=`realpath ${SHARE_DIR_PATH}/arch/${DEVICE_1}_${DEVICE_2}`
     export ARCH_DEF=${ARCH_DIR}/arch_${DEVICE_1}_${DEVICE_2}.xml

     # qlf* devices use different naming scheme than pp3* ones.
     export RR_GRAPH=${ARCH_DIR}/${DEVICE_1}.rr_graph.bin
     if [ ! -f ${RR_GRAPH} ]; then
	     export RR_GRAPH=${ARCH_DIR}/rr_graph_${DEVICE_1}_${DEVICE_2}.rr_graph.real.bin
     fi

     export PLACE_DELAY=${ARCH_DIR}/rr_graph_${DEVICE_1}_${DEVICE_2}.place_delay.bin
     export ROUTE_DELAY=${ARCH_DIR}/rr_graph_${DEVICE_1}_${DEVICE_2}.lookahead.bin

     export DEVICE_NAME=${DEVICE_1}

     if [[ "$DEVICE" == "qlf_k4n8_qlf_k4n8" ]]; then
	     VPR_OPTIONS="$VPR_OPTIONS
	     --route_chan_width 10
	     --clock_modeling ideal
	     --place_delta_delay_matrix_calculation_method dijkstra
	     --place_delay_model delta_override
	     --router_lookahead extended_map
	     --allow_dangling_combinational_nodes on
	     --absorb_buffer_luts off"
     else
	     VPR_OPTIONS="$VPR_OPTIONS
	     --route_chan_width 100
	     --clock_modeling route
	     --place_delay_model delta_override
	     --router_lookahead extended_map
	     --check_route quick
	     --strict_checks off
	     --allow_dangling_combinational_nodes on
	     --disable_errors check_unbuffered_edges:check_route
	     --congested_routing_iteration_threshold 0.8
	     --incremental_reroute_delay_ripup off
	     --base_cost_type delay_normalized_length_bounded
	     --bb_factor 10
	     --initial_pres_fac 4.0
	     --check_rr_graph off
	     --pack_high_fanout_threshold PB-LOGIC:18
	     --suppress_warnings ${OUT_NOISY_WARNINGS},sum_pin_class:check_unbuffered_edges:load_rr_indexed_data_T_values:check_rr_node:trans_per_R:check_route:set_rr_graph_tool_comment"
     fi
}

function run_vpr {
     set -e

     SDC_OPTIONS=""
     if [ ! -z $SDC ]
     then
          SDC_OPTIONS="--sdc_file $SDC"
     fi

     `which vpr` ${ARCH_DEF} \
         ${EBLIF} \
         --read_rr_graph ${RR_GRAPH} \
         --device ${DEVICE_NAME} \
         ${VPR_OPTIONS} \
         --read_router_lookahead ${ROUTE_DELAY} \
         --read_placement_delay_lookup ${PLACE_DELAY} \
         ${SDC_OPTIONS} \
         $@

     return $?
}

function run_genfasm {
     set -e

     `which genfasm` ${ARCH_DEF} \
         ${EBLIF} \
         --device ${DEVICE_NAME} \
         ${VPR_OPTIONS} \
         --read_rr_graph ${RR_GRAPH} \
         $@

     return $?
}
