#!/bin/bash
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
     elif [[ "$DEVICE" == "qlf_k6n10_qlf_k6n10" ]];then
	     DEVICE_1="qlf_k6n10-qlf_k6n10_gf12"
     fi
     export TOP=$TOP

     export ARCH_DIR=`realpath ${MYPATH}/../share/symbiflow/arch/${DEVICE_1}_${DEVICE_1}`
     export ARCH_DEF=${ARCH_DIR}/arch_${DEVICE_1}_${DEVICE_1}.xml
     export RR_GRAPH=${ARCH_DIR}/${DEVICE_1}.rr_graph.bin
     export PLACE_DELAY=${ARCH_DIR}/rr_graph_${DEVICE_1}_${DEVICE_1}.place_delay.bin
     export ROUTE_DELAY=${ARCH_DIR}/rr_graph_${DEVICE_1}_${DEVICE_1}.lookahead.bin

     export DEVICE_NAME=${DEVICE_1}

     export VPR_CONFIG=`realpath ${MYPATH}/../share/symbiflow/scripts/${FAMILY}/vpr_config.sh`
}

function run_vpr {
     set -e

     source ${VPR_CONFIG}

     SDC_OPTIONS=""
     if [ ! -z $SDC ]
     then
          SDC_OPTIONS="--sdc_file $SDC"
     fi

     vpr ${ARCH_DEF} \
         ${EBLIF} \
         --device ${DEVICE_NAME} \
         ${VPR_OPTIONS} \
         --read_rr_graph ${RR_GRAPH} \
         --read_placement_delay_lookup ${PLACE_DELAY} \
         --read_router_lookahead ${ROUTE_DELAY} \
         ${SDC_OPTIONS} \
         $@

     return $?
}

function run_genfasm {
     set -e

     source ${VPR_CONFIG}

     genfasm ${ARCH_DEF} \
         ${EBLIF} \
         --device ${DEVICE_NAME} \
         ${VPR_OPTIONS} \
         --read_rr_graph ${RR_GRAPH} \
         $@

     return $?
}
