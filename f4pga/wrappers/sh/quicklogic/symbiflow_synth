#!/bin/bash
set -e

MYPATH=`realpath $0`
MYPATH=`dirname ${MYPATH}`

SPLIT_INOUTS=`realpath ${MYPATH}/python/split_inouts.py`
CONVERT_OPTS=`realpath ${MYPATH}/python/convert_compile_opts.py`

print_usage () {
    echo "Usage: symbiflow_synth  -v|--verilog <Verilog file list>"
    echo "                       [-t|--top <top module name>]"
    echo "                       [-F|--family <device family>]"
    echo "                       [-d|--device <device type (e.g. qlf_k4n8)>]"
    echo "                       [-P|--part <part name>]"
    echo "                       [-p|--pcf <PCF IO constraints>]"
    echo "                       [-y <Verilog library search path>"
    echo "                       [+libext+<Verilog library file extension>]"
    echo "                       [+incdir+<Verilog include path>]"
    echo "                       [+define+<macro name>[=<macro value>]]"
    echo "                       [-f <additional compile command file>]"
    echo ""
    exit 1
}

VERILOG_FILES=()
TOP="top"
DEVICE=""
FAMILY=""
PART=""
PCF=""
EXTRA_ARGS=()

OPT=""
for arg in $@; do
    case $arg in
        -t|--top)
            OPT="top"
            ;;
        -v|--verilog)
            OPT="vlog"
            ;;
        -d|--device)
            OPT="dev"
            ;;
        -F|--family)
            OPT="family"
            ;;
        -P|--part)
            OPT="part"
            ;;
        -p|--pcf)
            OPT="pcf"
            ;;
        -y|-f|+incdir+*|+libext+*|+define+*)
            OPT="xtra"
            ;;
        *)
            case $OPT in
                "top")
                    TOP=$arg
                    OPT=""
                    ;;
                "vlog")
                    VERILOG_FILES+=($arg)
                    ;;
                "dev")
                    DEVICE=$arg
                    OPT=""
                    ;;
                "family")
                    FAMILY=$arg
                    OPT=""
                    ;;
                "part")
                    PART=$arg
                    OPT=""
                    ;;
                "pcf")
                    PCF=$arg
                    OPT=""
                    ;;
                "xtra")
                    ;;
                *)
                    print_usage
                    ;;
            esac
            ;;
    esac

    if [ "$OPT" == "xtra" ]; then
        EXTRA_ARGS+=($arg)
    fi

done

if [ -z ${FAMILY} ]; then
    echo "Please specify device family"
    exit 1
fi

if [ ${#VERILOG_FILES[@]} -eq 0 ]; then
	echo "Please provide at least one Verilog file"
	exit 1
fi

PINMAPCSV="pinmap_${PART}.csv"

export TECHMAP_PATH=`realpath ${MYPATH}/../share/symbiflow/techmaps/${FAMILY}`

SYNTH_TCL_PATH=`realpath ${MYPATH}/../share/symbiflow/scripts/${FAMILY}/synth.tcl`
CONV_TCL_PATH=`realpath ${MYPATH}/../share/symbiflow/scripts/${FAMILY}/conv.tcl`

export USE_ROI="FALSE"
export OUT_JSON=$TOP.json
export SYNTH_JSON=${TOP}_io.json
export OUT_SYNTH_V=${TOP}_synth.v
export OUT_EBLIF=${TOP}.eblif
export OUT_FASM_EXTRA=${TOP}_fasm_extra.fasm

if [ -s $PCF ]; then
    export PCF_FILE=$PCF
fi

DEVICE_PATH=`realpath ${MYPATH}/../share/symbiflow/arch/${DEVICE}_${DEVICE}`
export PINMAP_FILE=${DEVICE_PATH}/${PINMAPCSV}
if [ -d "${DEVICE_PATH}/cells" ]; then
	export DEVICE_CELLS_SIM=`find ${DEVICE_PATH}/cells -name "*_sim.v"`
	export DEVICE_CELLS_MAP=`find ${DEVICE_PATH}/cells -name "*_map.v"`
else
	# pp3 family has different directory naming scheme
	# the are named as ${DEVICE}_${PACKAGE}
	# ${PACKAGE} is not known because it is not passed down in add_binary_toolchain_test
	DEVICE_PATH=$(find $(realpath ${MYPATH}/../share/symbiflow/arch/) -type d -name "${DEVICE}*")
	export PINMAP_FILE=${DEVICE_PATH}/${PINMAPCSV}
	if [ -d "${DEVICE_PATH}/cells" ]; then
		export DEVICE_CELLS_SIM=`find ${DEVICE_PATH}/cells -name "*_sim.v"`
		export DEVICE_CELLS_MAP=`find ${DEVICE_PATH}/cells -name "*_map.v"`
	else
		export DEVICE_CELLS_SIM=
		export DEVICE_CELLS_MAP=
	fi
fi

YOSYS_COMMANDS=`echo ${EXTRA_ARGS[*]} | python3 ${CONVERT_OPTS}`
YOSYS_COMMANDS="${YOSYS_COMMANDS//$'\n'/'; '}"

LOG=${TOP}_synth.log

YOSYS_SCRIPT="tcl ${SYNTH_TCL_PATH}"

for f in ${VERILOG_FILES[*]}; do
    YOSYS_SCRIPT="read_verilog ${f}; $YOSYS_SCRIPT"
done

if [ ! -z "${YOSYS_COMMANDS}" ]; then
    YOSYS_SCRIPT="$YOSYS_COMMANDS; $YOSYS_SCRIPT"
fi

yosys -p "${YOSYS_SCRIPT}" -l $LOG
python3 ${SPLIT_INOUTS} -i ${OUT_JSON} -o ${SYNTH_JSON}
yosys -p "read_json $SYNTH_JSON; tcl ${CONV_TCL_PATH}"
