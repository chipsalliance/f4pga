#!/bin/bash

if [ -z $VPR_OPTIONS ]; then
     echo "Using default VPR options."
     VPR_OPTIONS="@VPR_ARGS@"
fi

function parse_args {

     OPTS=d:e:p:n:P:s:a:
     LONGOPTS=device:,eblif:,pcf:,net:,part:,sdc:,additional_vpr_options:

     PARSED_OPTS=`getopt --options=${OPTS} --longoptions=${LONGOPTS} --name $0 -- "$@"`
     eval set -- "${PARSED_OPTS}"

     DEVICE=""
     DEVICE_NAME=""
     PART=""
     EBLIF=""
     PCF=""
     NET=""
     SDC=""
     ADDITIONAL_VPR_OPTIONS=""

     while true; do
          case "$1" in
               -d|--device)
                    DEVICE=$2
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
               -s|--sdc)
                    SDC=$2
                    shift 2
                    ;;
               -a|--additional_vpr_options)
                    ADDITIONAL_VPR_OPTIONS="$2"
                    shift 2
		    ;;
               --)
                    break
                    ;;
          esac
     done

     if [ -z $DEVICE ] && [ -n $PART ]; then
          # Try to find device name. Accept only when exactly one is found
          PART_DIRS=(${MYPATH}/../share/symbiflow/arch/*/${PART})
          if [ ${#PART_DIRS[@]} -eq 1 ]; then
               DEVICE=$(basename $(dirname "${PART_DIRS[0]}"))
          fi
     fi
     if [ -z $DEVICE ]; then
          echo "Please provide device name"
          exit 1
     fi

     if [ -z $EBLIF ]; then
          echo "Please provide blif file name"
          exit 1
     fi

     export DEVICE=$DEVICE
     export EBLIF=$EBLIF
     export PCF=$PCF
     export NET=$NET
     export SDC=$SDC
     export VPR_OPTIONS="$VPR_OPTIONS $ADDITIONAL_VPR_OPTIONS"

     export ARCH_DIR=`realpath ${MYPATH}/../share/symbiflow/arch/$DEVICE`
     export ARCH_DEF=${ARCH_DIR}/arch.timing.xml
     export LOOKAHEAD=${ARCH_DIR}/rr_graph_${DEVICE}.lookahead.bin
     export RR_GRAPH=${ARCH_DIR}/rr_graph_${DEVICE}.rr_graph.real.bin
     export RR_GRAPH_XML=${ARCH_DIR}/rr_graph_${DEVICE}.rr_graph.real.xml
     export PLACE_DELAY=${ARCH_DIR}/rr_graph_${DEVICE}.place_delay.bin
     export DEVICE_NAME=`echo $DEVICE | sed -n 's/_/-/p'`
}

function run_vpr {
     set -e

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
         --read_router_lookahead ${LOOKAHEAD} \
         --read_placement_delay_lookup ${PLACE_DELAY} \
         ${SDC_OPTIONS} \
         $@

     return $?
}

function run_genfasm {
     set -e

     genfasm ${ARCH_DEF} \
         ${EBLIF} \
         --device ${DEVICE_NAME} \
         ${VPR_OPTIONS} \
         --read_rr_graph ${RR_GRAPH} \
         $@

     return $?
}

function run_vpr_xml_rr_graph {
     set -e

     vpr ${ARCH_DEF} \
          ${EBLIF} \
          --read_rr_graph ${RR_GRAPH}
          --write_rr_graph ${RR_GRAPH_XML}
          $@

     return $?
}
