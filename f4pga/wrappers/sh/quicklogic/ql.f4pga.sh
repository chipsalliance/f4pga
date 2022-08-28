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

VERSION="v2.0.1"

if [ ! -n $1 ]; then
  echo "Please enter a valid command: Refer help ql_symbiflow --help"
  exit 1
elif [[ $1 == "-synth" || $1 == "-compile" ]]; then
  echo -e "----------------- \n"
elif [[ $1 == "-h"  ||  $1 == "--help" ]];then
  echo -e "\nBelow are the supported commands: \n\
 To synthesize and dump a eblif file:\n\
\t>ql_symbiflow -synth -src <source_dir path> -d <device> -P <pinmap csv file> -t <top module name> -v <verilog file/files> -p <pcf file>\n\
 To run synthesis, pack, place and route:\n\
\t>ql_symbiflow -compile -src <source_dir path> -d <device> -P <pinmap csv file> -t <top module name> -v <verilog file/files> -p <pcf file> -P <pinmap csv file> -s <SDC file> \n\
Devices supported: ql-eos-s3, qlf_k4n8 \n\
Support temporarily disabled for: ql-pp3, qlf_k6n10" || exit
elif [[ $1 == "-v" || $1 == "--version" ]];then
  echo "Symbiflow Tool Version : ${VERSION}"
  exit 0
else
  echo -e "Please provide a valid command : Refer -h/--help\n"
  exit 1
fi


VERILOG_FILES=()
PCF=""
TOP=""
SOURCE=""
HELP=""
DEVICE=""
FAMILY=""
PART=""
SDC=""
OUT=()
ROUTE_FLAG0=""
MAX_CRITICALITY="0.0"
JSON=""
PNR_CORNER="slow"
ANALYSIS_CORNER="slow"
COMPILE_EXTRA_ARGS=()
BUILDDIR="build"
DEVICE_CHECK="INVALID"
OPT=""
RUN_TILL=""

for arg in $@; do
  case $arg in
  -src|--source)    OPT="src"  ;;
  -t|--top)         OPT="top"  ;;
  -v|--verilog)     OPT="vlog" ;;
  -d|--device)      OPT="dev"  ;;
  -p|--pcf)         OPT="pcf"  ;;
  -P|--part)        OPT="part" ;;
  -j|--json)        OPT="json" ;;
  -s|--sdc)         OPT="sdc"  ;;
  -r|--route_type)  OPT="route" ;;
  -pnr_corner)      OPT="pnr_corner" ;;
  -analysis_corner) OPT="analysis_corner" ;;
  -dump)            OPT="dump" ;;
  -synth|-compile)  OPT="synth" ;;
  -y|+incdir+*|+libext+*|+define+*) OPT="compile_xtra" ;;
  -f)                               OPT="options_file" ;;
  -build_dir)                       OPT="build_dir" ;;
  -h|--help) exit 0 ;;
  *)
    case $OPT in
      src)             SOURCE=$arg;          OPT="" ;;
      top)             TOP=$arg;             OPT="" ;;
      dev)             DEVICE=$arg;          OPT="" ;;
      pcf)             PCF=$arg;             OPT="" ;;
      part)            PART=$arg;            OPT="" ;;
      json)            JSON=$arg;            OPT="" ;;
      sdc)             SDC=$arg;             OPT="" ;;
      pnr_corner)      PNR_CORNER=$arg;      OPT="" ;;
      analysis_corner) ANALYSIS_CORNER=$arg; OPT="" ;;
      build_dir)       BUILDDIR=$arg         OPT="" ;;
      route)
        ROUTE_FLAG0="$arg"
        ROUTE_FLAG0="${ROUTE_FLAG0,,}"
        OPT=""
      ;;
      vlog) VERILOG_FILES+="$arg " ;;
      dump) OUT+="$arg " ;;
      compile_xtra) ;;
      options_file) COMPILE_EXTRA_ARGS+=("-f \"`realpath $arg`\" ") ;;
      *)
        echo "Refer help for more details: ql_symbiflow -h "
        exit 1
        ;;
    esac
  ;;
  esac
  if [ "$OPT" == "compile_xtra" ]; then
    COMPILE_EXTRA_ARGS+=($arg)
  fi
done

case ${DEVICE} in
  qlf_k4n8)  DEVICE="${DEVICE}_${DEVICE}"; FAMILY="qlf_k4n8";  DEVICE_CHECK="VALID"; USE_PINMAP=1 ;;
  qlf_k6n10) DEVICE="${DEVICE}_${DEVICE}"; FAMILY="qlf_k6n10"; DEVICE_CHECK="VALID"; USE_PINMAP=1 ;;
  ql-eos-s3) DEVICE="${DEVICE}";           FAMILY="pp3";       DEVICE_CHECK="VALID"; USE_PINMAP=0 ;;
  *) echo "Unsupported device '${DEVICE}'"; exit 1 ;;
esac

if [[ $1 == "-h" || $1 == "--help" ]];then
  exit 1
fi

## Check if the source directory exists
SOURCE=${SOURCE:-$PWD}
if [ $SOURCE == "." ];then
  SOURCE=$PWD
elif [ ! -d "$SOURCE" ];then
  echo "Directory path $SOURCE DOES NOT exists. Please add absolute path"
  exit 1
fi

if [ -f $SOURCE/v_list_tmp ];then
  rm -f $SOURCE/v_list_tmp
fi
if [ "$VERILOG_FILES" == "*.v" ];then
  VERILOG_FILES=`cd ${SOURCE};ls *.v`
fi
echo "$VERILOG_FILES" >${SOURCE}/v_list

## Validate the verlog source files
if [ ${#VERILOG_FILES[@]} -eq 0 ]; then
  echo "Please provide at least one Verilog file"
  exit 1
fi

echo "verilog files: $VERILOG_FILES"
echo $VERILOG_FILES >${SOURCE}/v_list
sed '/^$/d' $SOURCE/v_list > $SOURCE/f_list_temp
VERILOG_FILES=`cat $SOURCE/f_list_temp`


if [[ $1 == "-compile" || $1 == "-post_verilog" ]]; then
  if [ -z "$DEVICE" ]; then
    echo "DEVICE name is missing. Refer -h/--help"
    exit 1
  elif ! [[ "$DEVICE_CHECK" =~ ^(VALID)$ ]]; then
    echo "Invalid Device name, supported: ql-eos-s3, qlf_k4n8 \n\
      Support temporarily disabled for: qlf_k6n10"
    exit 1
  fi
  if [ -z "$TOP" ]; then
    echo "TOP module name is missing. Refer -h/--help"
    exit 1
  fi
  if [[  "$DEVICE_CHECK" =~ ^(VALID)$ ]]; then
    if [ -z "$PART" ]; then
      if [[ -n "$PCF" && $USE_PINMAP -ne 0 ]]; then
        echo "Error: pcf file cannot be used without declaring PINMAP CSV file"
        exit 1
      fi
    fi
  fi
  if [ -z "$ROUTE_FLAG0" ]; then
    MAX_CRITICALITY="0.0"
  elif ! [[ "$ROUTE_FLAG0" =~ ^(timing|congestion)$ ]]; then
    echo "Invalid option name, supported timing/congestion"
    exit 1
  else
    if [ "$ROUTE_FLAG0" == "congestion" ]; then
           MAX_CRITICALITY="0.99"
    else
    MAX_CRITICALITY="0.0"
    fi
  fi
fi

if [ ! -z "$SOURCE" ] && [ ! -d $SOURCE/$BUILDDIR ]; then
  mkdir -p $SOURCE/$BUILDDIR
fi

if [ ! -z "$OUT" ]; then
  OUT_ARR=($OUT)
fi

for item in $VERILOG_FILES; do
  if ! [ -f $SOURCE/$item ]; then
    echo "$item: verilog file does not exists at : $SOURCE"
    exit 1
  elif [[ $item =~ ^/ ]]; then
    echo "$item \\" >>$SOURCE/v_list_tmp
  else
    echo "\${current_dir}/$item \\" >>$SOURCE/v_list_tmp
  fi
done

if [ -f "$SOURCE/v_list_tmp" ]; then
  truncate -s-2 "$SOURCE/v_list_tmp"
  VERILOG_LIST=`cat ${SOURCE}/v_list_tmp`
fi

# FIXME: Some devices do not have fasm2bels yet
# FIXME: Some device do not support bitstream generation yet
RUN_TILL=""
if [[ "$DEVICE" =~ ^(qlf_k4n8.*)$ ]]; then
  HAVE_FASM2BELS=0
  RUN_TILL="bit"
elif [[ "$DEVICE" =~ ^(qlf_k6n10.*)$ ]]; then
  HAVE_FASM2BELS=0
  RUN_TILL="route"
elif [[ "$DEVICE" =~ ^(ql-eos-s3)$ ]]; then
  HAVE_FASM2BELS=1
  RUN_TILL="bit"
else
  HAVE_FASM2BELS=0
  RUN_TILL="route"
fi

# For some devices do repacking between place and route
if [[ "$DEVICE" =~ ^(qlf_k4n8.*)$ ]]; then
  TOP_FINAL=${TOP}.repacked
else
  TOP_FINAL=${TOP}
fi

export PCF_FILE=$PCF
export JSON=$JSON
export PINMAP_FILE=$PINMAPCSV
export MAX_CRITICALITY=$MAX_CRITICALITY

## Create Makefile

if [[ $SOURCE =~ ^/ ]]; then
  CURR_DIR="${SOURCE}"
else
  CURR_DIR="${PWD}/${SOURCE}"
fi

if [[ -n "$PART" && $USE_PINMAP -ne 0 ]]; then
  if [[ -f $SOURCE/$PART ]];then
    CSV_PATH=`realpath $SOURCE/$PART`
  elif [[ -f $PART ]];then
    CSV_PATH=`realpath $PART`
  else
    echo "invalid csv file/path"
    exit 1
  fi
fi

if [[ -f $SOURCE/$JSON ]];then
  JSON_PATH=`realpath $SOURCE/$JSON`
elif [[ -f $JSON ]];then
  JSON_PATH=`realpath $JSON`
else
  JSON_PATH=""
fi

if [[ -f $SOURCE/$PCF ]];then
  PCF_PATH=`realpath $SOURCE/$PCF`
elif [[ -f $PCF ]];then
  PCF_PATH=`realpath $PCF`
fi

if [[ $USE_PINMAP -ne 0 ]]; then
  export PART=${CSV_PATH}
else
  export PART=${PART}
fi
export JSON=${JSON_PATH}
export PCF_PATH=${PCF_PATH}

MAKE_FILE=${CURR_DIR}/Makefile.symbiflow
LOG_FILE=${CURR_DIR}/${BUILDDIR}/${TOP}.log

if [ -f "$SOURCE"/$PCF_FILE ];then
  PCF_MAKE="\${current_dir}/$PCF_FILE"
else
  touch ${CURR_DIR}/${BUILDDIR}/${TOP}_dummy.pcf
  PCF_MAKE="\${current_dir}/${BUILDDIR}/${TOP}_dummy.pcf"
fi

PROCESS_SDC="$F4PGA_SHARE_DIR"/scripts/process_sdc_constraints.py
if ! [ -z "$SDC" ]; then
  if ! [ -f "$SOURCE"/$SDC ];then
    echo "The sdc file: $SDC is missing at: $SOURCE"
    exit 1
  else
    SDC_MAKE="$SOURCE/$SDC"
  fi
else
  touch ${CURR_DIR}/${BUILDDIR}/${TOP}_dummy.sdc
  SDC_MAKE="\${current_dir}/${BUILDDIR}/${TOP}_dummy.sdc"
fi

if ! [ -z "$CSV_PATH" ]; then
  CSV_MAKE=$CSV_PATH
else
  touch ${CURR_DIR}/${BUILDDIR}/${TOP}_dummy.csv
  CSV_MAKE="\${current_dir}/${BUILDDIR}/${TOP}_dummy.csv"
fi

echo -e ".PHONY:\${BUILDDIR}\n
current_dir := $CURR_DIR\n\
TOP := $TOP\n\
JSON := $JSON\n\
TOP_FINAL := $TOP_FINAL\n\
VERILOG := $VERILOG_LIST \n\
PARTNAME := $PART\n\
DEVICE  := $DEVICE\n\
FAMILY := $FAMILY\n\
ANALYSIS_CORNER := $PNR_CORNER\n\
PNR_CORNER := $ANALYSIS_CORNER\n\
PCF := $PCF_MAKE\n\
PINMAP_CSV := $CSV_MAKE\n\
SDC_IN := $SDC_MAKE\n\
BUILDDIR := $BUILDDIR\n\n\
SDC := \${current_dir}/\${BUILDDIR}/\${TOP}.sdc

all: \${BUILDDIR}/\${TOP}.${RUN_TILL}\n\
\n\
\${BUILDDIR}/\${TOP}.eblif: \${VERILOG} \${PCF}\n\
  ifneq (\"\$(wildcard \$(HEX_FILES))\",\"\")\n\
	\$(shell cp \${current_dir}/*.hex \${BUILDDIR})\n\
  endif\n\
	cd \${BUILDDIR} && symbiflow_synth -t \${TOP} -v \${VERILOG} -F \${FAMILY} -d \${DEVICE} -p \${PCF} -P \${PART} ${COMPILE_EXTRA_ARGS[*]} > $LOG_FILE 2>&1\n\
\n\
\${BUILDDIR}/\${TOP}.sdc: \${BUILDDIR}/\${TOP}.eblif\n\
	python3 ${PROCESS_SDC} --sdc-in \${SDC_IN} --sdc-out \$@ --pcf \${PCF} --eblif \${BUILDDIR}/\${TOP}.eblif --pin-map \${PINMAP_CSV}\n\
\n\
\${BUILDDIR}/\${TOP}.net: \${BUILDDIR}/\${TOP}.eblif \${BUILDDIR}/\${TOP}.sdc\n\
	cd \${BUILDDIR} && symbiflow_pack -e \${TOP}.eblif -f \${FAMILY} -d \${DEVICE} -s \${SDC} -c \${PNR_CORNER} >> $LOG_FILE 2>&1\n\
\n\
\${BUILDDIR}/\${TOP}.place: \${BUILDDIR}/\${TOP}.net \${PCF}\n\
	cd \${BUILDDIR} && symbiflow_place -e \${TOP}.eblif -f \${FAMILY} -d \${DEVICE} -p \${PCF} -n \${TOP}.net -P \${PARTNAME} -s \${SDC} -c \${PNR_CORNER} >> $LOG_FILE 2>&1\n\
" >$MAKE_FILE

if [ "$TOP" != "$TOP_FINAL" ]; then
	if [ -z "$JSON" ];then
    echo -e "\
\${BUILDDIR}/\${TOP_FINAL}.place: \${BUILDDIR}/\${TOP}.eblif \${BUILDDIR}/\${TOP}.net \${BUILDDIR}/\${TOP}.place\n\
	cd \${BUILDDIR} && symbiflow_repack -e \${TOP}.eblif -n \${TOP}.net -f \${FAMILY} -d \${DEVICE} -c \${PNR_CORNER} >> $LOG_FILE 2>&1\n\
    " >>$MAKE_FILE
      else
    echo -e "\
\${BUILDDIR}/\${TOP_FINAL}.place: \${BUILDDIR}/\${TOP}.eblif \${BUILDDIR}/\${TOP}.net \${BUILDDIR}/\${TOP}.place\n\
	cd \${BUILDDIR} && symbiflow_repack -e \${TOP}.eblif -n \${TOP}.net -f \${FAMILY} -d \${DEVICE} -j \${JSON} -c \${PNR_CORNER} >> $LOG_FILE 2>&1\n\
    " >>$MAKE_FILE
       fi
fi

    echo -e "\
\${BUILDDIR}/\${TOP_FINAL}.route: \${BUILDDIR}/\${TOP_FINAL}.place\n\
	cd \${BUILDDIR} && symbiflow_route -e \${TOP_FINAL}.eblif -f \${FAMILY} -d \${DEVICE} -s \${SDC} -c \${PNR_CORNER} >> $LOG_FILE 2>&1\n\
\n\
\${BUILDDIR}/\${TOP}.post_v: \${BUILDDIR}/\${TOP_FINAL}.route\n\
	cd \${BUILDDIR} && symbiflow_analysis -e \${TOP_FINAL}.eblif -f \${FAMILY} -d \${DEVICE} -s \${SDC} -t \${TOP} -c \${ANALYSIS_CORNER} >> $LOG_FILE 2>&1\n\
\n\
\${BUILDDIR}/\${TOP}.fasm: \${BUILDDIR}/\${TOP_FINAL}.route\n\
	cd \${BUILDDIR} && symbiflow_write_fasm -e \${TOP_FINAL}.eblif -f \${FAMILY} -d \${DEVICE} -s \${SDC} -c \${PNR_CORNER} >> $LOG_FILE 2>&1\n\
    " >>$MAKE_FILE

# Bitstream
if [ "$FAMILY" == "qlf_k4n8" ]; then
    echo -e "\
\${BUILDDIR}/\${TOP}.bit: \${BUILDDIR}/\${TOP}.fasm\n\
	cd \${BUILDDIR} && symbiflow_generate_bitstream -d \${FAMILY} -f \${TOP}.fasm -r 4byte -b \${TOP}.bit >> $LOG_FILE 2>&1\n\
	cd \${BUILDDIR} && symbiflow_generate_bitstream -d \${FAMILY} -f \${TOP}.fasm -r txt -b \${TOP}.bin >> $LOG_FILE 2>&1\n\
\n\
\${BUILDDIR}/\${DEVICE}.lib:\n\
	cd \${BUILDDIR} && symbiflow_generate_libfile \${PARTNAME} \${DEVICE} \${PNR_CORNER} >> $LOG_FILE 2>&1\n\
" >>$MAKE_FILE

elif [ "$FAMILY" == "pp3" ]; then
    echo -e "\
\${BUILDDIR}/\${TOP}.bit: \${BUILDDIR}/\${TOP}.fasm\n\
	cd \${BUILDDIR} && symbiflow_generate_bitstream -d \${DEVICE} -f \${TOP}.fasm -b \${TOP}.bit >> $LOG_FILE 2>&1\n\
    " >>$MAKE_FILE
fi

# EOS-S3 specific targets
if [ "$DEVICE" == "ql-eos-s3" ]; then
    echo -e "\
\${BUILDDIR}/\${TOP}_bit.h: \${BUILDDIR}/\${TOP}.bit\n\
	symbiflow_write_bitheader \$^ \$@ >> $LOG_FILE 2>&1\n\
\n\
\${BUILDDIR}/\${TOP}.bin: \${BUILDDIR}/\${TOP}.bit\n\
	symbiflow_write_binary \$^ \$@ >> $LOG_FILE 2>&1\n\
\n\
\${BUILDDIR}/\${TOP}.jlink: \${BUILDDIR}/\${TOP}.bit\n\
	symbiflow_write_jlink \$^ \$@ >> $LOG_FILE 2>&1\n\
\n\
\${BUILDDIR}/\${TOP}.openocd: \${BUILDDIR}/\${TOP}.bit\n\
	symbiflow_write_openocd \$^ \$@ >> $LOG_FILE 2>&1\n\
\n\
    " >>$MAKE_FILE
fi

# fasm2bels
if [ "$HAVE_FASM2BELS" != 0 ]; then
    echo -e "\
\${BUILDDIR}/\${TOP}.bit.v: \${BUILDDIR}/\${TOP}.bit\n\
	cd \${BUILDDIR} && symbiflow_fasm2bels -b \${TOP}.bit -d \${DEVICE} -p \${PCF} -P \${PARTNAME} >> $LOG_FILE 2>&1\n\
    " >>$MAKE_FILE
fi

echo -e "\
clean:\n\
	rm -rf \${BUILDDIR}\n\
   " >>$MAKE_FILE

## Remove temporary files
rm -f $SOURCE/f_list_temp $SOURCE/v_list_tmp $SOURCE/v_list

## Make file Targets
if [ $1 == "-synth" ]; then
  echo -e "Performing Synthesis "
  cd $SOURCE;make -f Makefile.symbiflow ${BUILDDIR}/${TOP}.eblif || (cat $LOG_FILE && exit 1)
elif [[ ! -z "$OUT" && $1 == "-compile" ]];then
  if [[ " ${OUT_ARR[@]} " =~ " post_verilog " ]];then
    cd $SOURCE;make -f Makefile.symbiflow ${BUILDDIR}/${TOP}.post_v || (cat $LOG_FILE && exit 1)
  fi
  if [ "$DEVICE" == "ql-eos-s3" ]; then
    if [[ " ${OUT_ARR[@]} " =~ " jlink " ]]; then
     cd $SOURCE;make -f Makefile.symbiflow ${BUILDDIR}/${TOP}.jlink || (cat $LOG_FILE && exit 1)
    fi
    if [[ " ${OUT_ARR[@]} " =~ " openocd " ]]; then
     cd $SOURCE;make -f Makefile.symbiflow ${BUILDDIR}/${TOP}.openocd || (cat $LOG_FILE && exit 1)
    fi
    if [[ " ${OUT_ARR[@]} " =~ " post_verilog " ]]; then
     cd $SOURCE;make -f Makefile.symbiflow  ${BUILDDIR}/${TOP}.bit.v || (cat $LOG_FILE && exit 1)
    fi
    if [[ " ${OUT_ARR[@]} " =~ " header " ]]; then
     cd $SOURCE;make -f Makefile.symbiflow ${BUILDDIR}/${TOP}_bit.h || (cat $LOG_FILE && exit 1)
    fi
    if [[ " ${OUT_ARR[@]} " =~ " binary " ]]; then
     cd $SOURCE;make -f Makefile.symbiflow ${BUILDDIR}/${TOP}.bin || (cat $LOG_FILE && exit 1)
    fi
  fi
else
  if [ $1 == "-compile" ]; then
    echo -e "Running Synth->Pack->Place->Route->FASM->bitstream"
    cd $SOURCE;make -f Makefile.symbiflow ${BUILDDIR}/${TOP}.${RUN_TILL} || (cat $LOG_FILE && exit 1)
  fi
fi
