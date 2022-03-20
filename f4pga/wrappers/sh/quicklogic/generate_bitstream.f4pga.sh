#!/usr/bin/env bash

set -e

OPTS=d:f:r:b:
LONGOPTS=device:,fasm:,format:,bit:

PARSED_OPTS=`getopt --options=${OPTS} --longoptions=${LONGOPTS} --name $0 -- "$@"`
eval set -- "${PARSED_OPTS}"

DEVICE=""
FASM=""
BIT=""
BIT_FORMAT="4byte"

while true; do
  case "$1" in
    -d|--device) DEVICE=$2;     shift 2;;
    -f|--fasm)   FASM=$2;       shift 2;;
    -r|--format) BIT_FORMAT=$2; shift 2;;
    -b|--bit)    BIT=$2;        shift 2;;
    --) break;;
  esac
done

if [ -z $DEVICE ]; then
  echo "Please provide device name"
  exit 1
fi

if [ -z $FASM ]; then
  echo "Please provide an input FASM file name"
  exit 1
fi

if [ -z $BIT ]; then
  echo "Please provide an output bistream file name"
  exit 1
fi

DB_ROOT=$(f4pga-env share)/fasm_database/${DEVICE}

`which qlf_fasm` --db-root ${DB_ROOT} --format ${BIT_FORMAT} --assemble $FASM $BIT
