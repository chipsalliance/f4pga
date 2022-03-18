#!/bin/bash

set -e


MYPATH=$(dirname "$(readlink -f "$BASH_SOURCE")")
BUILDDIR=build

source ${MYPATH}/env
source ${VPRPATH}/vpr_common
VERSION="v2.0.1"

if [ ! -n $1 ]; then
echo "Please enter a valid command: Refer help ql_symbiflow --help"
exit 0
elif [[ $1 == "-synth" || $1 == "-compile" ]]; then
echo -e "----------------- \n"
elif [[ $1 == "-h"  ||  $1 == "--help" ]];then
echo -e "\nBelow are the supported commands: \n\
 To synthesize and dump a eblif file:\n\
\t>ql_symbiflow -synth -src <source_dir path> -d <device> -P <pinmap csv file> -t <top module name> -v <verilog file/files> -p <pcf file>\n\
 To run synthesis, pack, place and route:\n\
\t>ql_symbiflow -compile -src <source_dir path> -d <device> -P <pinmap csv file> -t <top module name> -v <verilog file/files> -p <pcf file> -P <pinmap csv file> -s <SDC file> \n\
Device supported:qlf_k4n8" || exit
elif [[ $1 == "-v" || $1 == "--version" ]];then
        echo "Symbiflow Tool Version : ${VERSION}"
        exit
else
echo -e "Please provide a valid command : Refer -h/--help\n"
exit
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

OPT=""
for arg in $@; do
    case $arg in
		-src|--source)
            OPT="src"
            ;;
		-t|--top)
            OPT="top"
            ;;
		-v|--verilog)
            OPT="vlog"
            ;;
		-d|--device)
            OPT="dev"
            ;;
		-p|--pcf)
            OPT="pcf"
            ;;
		-P|--part)
            OPT="part"
            ;;
		-j|--json)
            OPT="json"
            ;;
		-s|--sdc)
            OPT="sdc"
            ;;
		-r|--route_type)
            OPT="route"
            ;;
		-pnr_corner)
            OPT="pnr_corner"
            ;;
		-analysis_corner)
            OPT="analysis_corner"
            ;;
		-dump)
            OPT="dump"
            ;;
		-synth|-compile)
            OPT="synth"
            ;;
        -y|+incdir+*|+libext+*|+define+*)
            OPT="compile_xtra"
            ;;
        -f)
            OPT="options_file"
            ;;
		-h|--help)
            exit 0
            ;;
        *)
            case $OPT in
                "src")
                    SOURCE=$arg
                    OPT=""
                    ;;
                "top")
                    TOP=$arg
                    OPT=""
                    ;;
                "vlog")
                    VERILOG_FILES+="$arg "
                    ;;
                "dev")
                    DEVICE=$arg
                    OPT=""
                    ;;
                "pcf")
                    PCF=$arg
                    OPT=""
                    ;;
                "part")
                    PART=$arg
                    OPT=""
                    ;;
                "json")
                    JSON=$arg
                    OPT=""
                    ;;
                "sdc")
                    SDC=$arg
                    OPT=""
                    ;;
                "route")
                    ROUTE_FLAG0="$arg"
                    ROUTE_FLAG0="${ROUTE_FLAG0,,}"
                    OPT=""
                    ;;
                "pnr_corner")
                    PNR_CORNER=$arg
                    OPT=""
                    ;;
                "analysis_corner")
                    ANALYSIS_CORNER=$arg
                    OPT=""
                    ;;
                "dump")
                    OUT+="$arg "
                    ;;
                "compile_xtra")
                    ;;
                "options_file")
                    COMPILE_EXTRA_ARGS+=("-f \"`realpath $arg`\" ")
                    ;;
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
	qlf_k4n8)
        DEVICE="${DEVICE}_${DEVICE}"
		FAMILY="qlf_k4n8"
		;;
	ql-eos-s3)
        DEVICE="${DEVICE}"
		FAMILY="pp3"
		;;
	*)
		echo "Unsupported device '${DEVICE}'"
		exit 1
		;;
esac

##### Check if the source directory exists #####
if [[ $1 == "-h" || $1 == "--help" ]];then
    exit 1
else
    if [ -z "$SOURCE" ];then
    SOURCE=$PWD
    elif [ $SOURCE == "." ];then
    SOURCE=$PWD
    elif [ ! -d "$SOURCE" ];then
    echo "Directory path $SOURCE DOES NOT exists. Please add absolute path"
    exit 1
    fi

if [[ $1 == "-h"  ||  $1 == "--help" ]];then
exit 0
else
if [ -f $SOURCE/v_list_tmp ];then
rm -f $SOURCE/v_list_tmp
fi
if [ $VERILOG_FILES == "*.v" ];then
        VERILOG_FILES=`cd ${SOURCE};ls *.v`
fi
echo "$VERILOG_FILES" >${SOURCE}/v_list
fi

##### Validate the verlog source files #####

if [ ${#VERILOG_FILES[@]} -eq 0 ]; then
       if [[ $1 != "-h" || $1 != "--help" ]];then
	echo "Please provide at least one Verilog file"
	exit 1
       fi
else
	echo "verilog files: $VERILOG_FILES"
	echo $VERILOG_FILES >${SOURCE}/v_list
	sed '/^$/d' $SOURCE/v_list > $SOURCE/f_list_temp
	VERILOG_FILES=`cat $SOURCE/f_list_temp`
fi
fi

if [[ $1 == "-compile" || $1 == "-post_verilog" ]]; then
  # Allow no PCF/pinmap for some devices
  if [[ ! "$DEVICE" =~ ^(qlf_k4n8_qlf_k4n8)$ ]]; then
    if [ -z "$PCF" ]; then
      echo "PCF file option is missing. Refer -h/--help"
      exit 1
    elif ! [ -f "$SOURCE/$PCF" ]; then
      echo "The pcf file: $PCF is missing at: $SOURCE"
      exit 1
    fi
  fi
  if [ -z "$DEVICE" ]; then
    echo "DEVICE name is missing. Refer -h/--help"
    exit 1
  elif ! [[ "$DEVICE" =~ ^(qlf_k4n8_qlf_k4n8)$ ]]; then
	  echo "Invalid Device name, supported qlf_k4n8"
    exit 1
  fi
  if [ -z "$TOP" ]; then
    echo "TOP module name is missing. Refer -h/--help"
    exit 1
  fi
  if [[  "$DEVICE" =~ ^(qlf_k4n8_qlf_k4n8)$ ]]; then
    if [ -z "$PART" ]; then
	   if [ -n "$PCF" ];then
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

if [ ! -z "$SOURCE" ];then
	if [ ! -d $SOURCE/$BUILDDIR ]; then
	mkdir -p $SOURCE/$BUILDDIR
	fi
fi

if [ ! -z "$OUT" ];then
OUT_ARR=($OUT)
fi

for item in $VERILOG_FILES;
do
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
RUN_TILL=""
if [[ "$DEVICE" =~ ^(qlf_k4n8.*)$ ]]; then
    HAVE_FASM2BELS=0
    RUN_TILL="bit"
else
    HAVE_FASM2BELS=1
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
export TOP_F=$TOP
export PINMAP_FILE=$PINMAPCSV
export MAX_CRITICALITY=$MAX_CRITICALITY
##### Create Makefile #####

if [[ $SOURCE =~ ^/ ]]; then
	CURR_DIR="${SOURCE}"
else
	CURR_DIR="${PWD}/${SOURCE}"
fi

if [ -n "$PART" ]; then
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

export PART=${CSV_PATH}
export JSON=${JSON_PATH}
export PCF_PATH=${PCF_PATH}

MAKE_FILE=${CURR_DIR}/Makefile.symbiflow
LOG_FILE=${CURR_DIR}/${BUILDDIR}/${TOP}.log

if [ -f "$SOURCE"/$PCF_FILE ];then
	PCF_MAKE="\${current_dir}/$PCF_FILE"
else
    touch ${CURR_DIR}/build/${TOP}_dummy.pcf
    PCF_MAKE="\${current_dir}/build/${TOP}_dummy.pcf"
fi

PROCESS_SDC=`realpath ${MYPATH}/python/process_sdc_constraints.py`
if ! [ -z "$SDC" ]; then
    if ! [ -f "$SOURCE"/$SDC ];then
        echo "The sdc file: $SDC is missing at: $SOURCE"
        exit 1
    else
        SDC_MAKE="$SOURCE/$SDC"
    fi
else
    touch ${CURR_DIR}/build/${TOP}_dummy.sdc
    SDC_MAKE="\${current_dir}/build/${TOP}_dummy.sdc"
fi

if ! [ -z "$CSV_PATH" ]; then
    CSV_MAKE=$CSV_PATH
else
    touch ${CURR_DIR}/build/${TOP}_dummy.csv
    CSV_MAKE="\${current_dir}/build/${TOP}_dummy.csv"
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
BUILDDIR := build\n\n\
SDC := \${current_dir}/\${BUILDDIR}/\${TOP}.sdc

all: \${BUILDDIR}/\${TOP}.${RUN_TILL}\n\
\n\
\${BUILDDIR}/\${TOP}.eblif: \${VERILOG} \${PCF}\n\
  ifneq (\"\$(wildcard \$(HEX_FILES))\",\"\")\n\
	\$(shell cp \${current_dir}/*.hex \${BUILDDIR})\n\
  endif\n\
	cd \${BUILDDIR} && symbiflow_synth -t \${TOP} -v \${VERILOG} -F \${FAMILY} -d \${DEVICE} -p \${PCF} ${COMPILE_EXTRA_ARGS[*]} > $LOG_FILE 2>&1\n\
\n\
\${BUILDDIR}/\${TOP}.sdc: \${BUILDDIR}/\${TOP}.eblif\n\
	python3 ${PROCESS_SDC} --sdc-in \${SDC_IN} --sdc-out \$@ --pcf \${PCF} --eblif \${BUILDDIR}/\${TOP}.eblif --pin-map \${PINMAP_CSV}\n\
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
\n\
\${BUILDDIR}/\${TOP}.bit: \${BUILDDIR}/\${TOP}.fasm\n\
	cd \${BUILDDIR} && symbiflow_generate_bitstream -d \${FAMILY} -f \${TOP}.fasm -r 4byte -b \${TOP}.bit >> $LOG_FILE 2>&1\n\
	cd \${BUILDDIR} && symbiflow_generate_bitstream -d \${FAMILY} -f \${TOP}.fasm -r txt -b \${TOP}.bin >> $LOG_FILE 2>&1\n\
\n\
\${BUILDDIR}/\${DEVICE}.lib:\n\
	cd \${BUILDDIR} && symbiflow_generate_libfile \${PARTNAME} \${DEVICE} \${PNR_CORNER} >> $LOG_FILE 2>&1\n\
" >>$MAKE_FILE

if [ "$HAVE_FASM2BELS" != 0 ]; then
    echo -e "\
	cd \${BUILDDIR} && symbiflow_write_fasm2bels -e \${TOP}.eblif -d \${DEVICE} -p \${PCF} -n \${TOP}.net -P \${PARTNAME}\n\
    " >>$MAKE_FILE
fi

echo -e "\
clean:\n\
	rm -rf \${BUILDDIR}\n\
" >>$MAKE_FILE

#### Remove temporary files #####
rm -f $SOURCE/f_list_temp $SOURCE/v_list_tmp $SOURCE/v_list

##### Make file Targets #####
if [ $1 == "-synth" ]; then
  echo -e "Performing Synthesis "
  cd $SOURCE;make -f Makefile.symbiflow ${BUILDDIR}/${TOP}.eblif || exit
elif [[ ! -z "$OUT" && $1 == "-compile" ]];then
	if [[ " ${OUT_ARR[@]} " =~ " post_verilog " ]];then
		cd $SOURCE;make -f Makefile.symbiflow ${BUILDDIR}/${TOP}.post_v || exit
	fi
else
  if [ $1 == "-compile" ]; then
  echo -e "Running Synth->Pack->Place->Route->FASM->bitstream"
  	cd $SOURCE;make -f Makefile.symbiflow ${BUILDDIR}/${TOP}.${RUN_TILL}  || exit
  fi
fi


###############################################################################################


