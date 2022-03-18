#!/bin/bash
set -e

MYPATH=`realpath $0`
MYPATH=`dirname ${MYPATH}`

export SHARE_DIR_PATH=`realpath ${MYPATH}/../share/symbiflow`
export TECHMAP_PATH=${SHARE_DIR_PATH}/techmaps/xc7_vpr/techmap


export UTILS_PATH=${SHARE_DIR_PATH}/scripts
SYNTH_TCL_PATH=${UTILS_PATH}/xc7/synth.tcl
CONV_TCL_PATH=${UTILS_PATH}/xc7/conv.tcl
SPLIT_INOUTS=${UTILS_PATH}/split_inouts.py

VERILOG_FILES=()
XDC_FILES=()
TOP=top
DEVICE="*"
PART=""
SURELOG_CMD=()

VERILOGLIST=0
XDCLIST=0
TOPNAME=0
DEVICENAME=0
PARTNAME=0
SURELOG=0

for arg in $@; do
	echo $arg
	case "$arg" in
		-t|--top)
			echo "adding top"
			VERILOGLIST=0
			XDCLIST=0
			TOPNAME=1
			DEVICENAME=0
			PARTNAME=0
			SURELOG=0
			;;
		-x|--xdc)
			VERILOGLIST=0
			XDCLIST=1
			TOPNAME=0
			DEVICENAME=0
			PARTNAME=0
			SURELOG=0
			;;
		-v|--verilog)
			VERILOGLIST=1
			XDCLIST=0
			TOPNAME=0
			DEVICENAME=0
			PARTNAME=0
			SURELOG=0
			;;
		-d|--device)
			VERILOGLIST=0
			XDCLIST=0
			TOPNAME=0
			DEVICENAME=1
			PARTNAME=0
			SURELOG=0
			;;
		-p|--part)
			VERILOGLIST=0
			XDCLIST=0
			TOPNAME=0
			DEVICENAME=0
			PARTNAME=1
			SURELOG=0
			;;
		-s|--surelog)
			VERILOGLIST=0
			XDCLIST=0
			TOPNAME=0
			DEVICENAME=0
			PARTNAME=0
			SURELOG=1
			;;
		*)
			if [ $VERILOGLIST -eq 1 ]; then
				VERILOG_FILES+=($arg)
			elif [ $XDCLIST -eq 1 ]; then
				XDC_FILES+=($arg)
			elif [ $TOPNAME -eq 1 ]; then
				TOP=$arg
			elif [ $DEVICENAME -eq 1 ]; then
				DEVICE=$arg
			elif [ $PARTNAME -eq 1 ]; then
				PART=$arg
			elif [ $SURELOG -eq 1 ]; then
				SURELOG_CMD+=($arg)
			else
				echo "Usage: synth [-t|--top <top module name> -v|--verilog <Verilog files list> [-x|--xdc <XDC files list>]"
				echo "             [-d|--device <device type (e.g. artix7)>] [-p|--part <part name>] [-s|--surelog] <parameters to surelog>"
				echo "note: device and part parameters are required if xdc is passed"
				exit 1
			fi
			;;
	esac
done

if [ ${#VERILOG_FILES[@]} -eq 0 ]; then
	echo "Please provide at least one Verilog file"
	exit 1
fi

DATABASE_DIR=${DATABASE_DIR:=$(prjxray-config)}

export TOP=${TOP}
export USE_ROI="FALSE"
export INPUT_XDC_FILES=${XDC_FILES[*]}
export OUT_JSON=$TOP.json
export OUT_SDC=${TOP}.sdc
export SYNTH_JSON=${TOP}_io.json
export OUT_SYNTH_V=${TOP}_synth.v
export OUT_EBLIF=${TOP}.eblif
export PART_JSON=`realpath ${DATABASE_DIR}/$DEVICE/$PART/part.json`
export OUT_FASM_EXTRA=${TOP}_fasm_extra.fasm
export PYTHON3=${PYTHON3:=$(which python3)}
LOG=${TOP}_synth.log
if [ -z "$SURELOG_CMD" ]; then
yosys -p "tcl ${SYNTH_TCL_PATH}" -l $LOG ${VERILOG_FILES[*]}
else
yosys -p "plugin -i uhdm" -p "read_verilog_with_uhdm ${SURELOG_CMD[*]} ${VERILOG_FILES[*]}" -p "tcl ${SYNTH_TCL_PATH}" -l $LOG
fi
python3 ${SPLIT_INOUTS} -i ${OUT_JSON} -o ${SYNTH_JSON}
yosys -p "read_json $SYNTH_JSON; tcl ${CONV_TCL_PATH}"
