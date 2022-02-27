#!/usr/bin/env bash

set -e

F4PGA_FAM=${F4PGA_FAM:=xc7}

case "$F4PGA_FAM" in
  xc7) F4PGA_DIR_ROOT='install';;
  eos-s3) F4PGA_DIR_ROOT='quicklogic-arch-defs';;
esac

export PATH="$F4PGA_INSTALL_DIR/$F4PGA_FAM/$F4PGA_DIR_ROOT/bin:$PATH"
source "$F4PGA_INSTALL_DIR/$F4PGA_FAM/conda/etc/profile.d/conda.sh"

conda activate $F4PGA_FAM
