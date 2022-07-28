#!/usr/bin/env bash

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

echo '::group::Install dependencies'
sudo apt update -y
sudo apt install -y git wget xz-utils
echo '::endgroup::'


echo '::group::Clone f4pga-examples'
git clone --recurse-submodules https://github.com/chipsalliance/f4pga-examples
cd f4pga-examples
echo '::endgroup::'


FPGA_FAM=${FPGA_FAM:=xc7}

echo '::group::Install Miniconda3'
wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O conda_installer.sh

F4PGA_INSTALL_DIR_FAM="$F4PGA_INSTALL_DIR/$FPGA_FAM"

bash conda_installer.sh -u -b -p "$F4PGA_INSTALL_DIR_FAM"/conda
source "$F4PGA_INSTALL_DIR_FAM"/conda/etc/profile.d/conda.sh
echo '::endgroup::'


echo '::group::Create environment'
conda env create -f "$FPGA_FAM"/environment.yml
echo '::endgroup::'


echo '::group::Install arch-defs'
case "$FPGA_FAM" in
  xc7)
    mkdir -p "$F4PGA_INSTALL_DIR_FAM"/install
    F4PGA_TIMESTAMP='20220714-173445'
    F4PGA_HASH='f7afc12'
    for PKG in install xc7a50t_test; do
      wget -qO- https://storage.googleapis.com/symbiflow-arch-defs/artifacts/prod/foss-fpga-tools/symbiflow-arch-defs/continuous/install/${F4PGA_TIMESTAMP}/symbiflow-arch-defs-${PKG}-${F4PGA_HASH}.tar.xz | tar -xJC $F4PGA_INSTALL_DIR/xc7/install
    done
  ;;
  eos-s3)
    wget -qO- https://storage.googleapis.com/symbiflow-arch-defs-install/quicklogic-arch-defs-qlf-fc5d8da.tar.gz | tar -xz -C $F4PGA_INSTALL_DIR_FAM
  ;;
esac
echo '::endgroup::'


cd ..


echo '::group::Add f4pga-env'

F4PGA_DIR_ROOT='install'

F4PGA_DIR_BIN="$F4PGA_INSTALL_DIR_FAM/$F4PGA_DIR_ROOT"/bin/
mkdir -p "$F4PGA_DIR_BIN"
cp $(dirname "$0")/../../f4pga-env "$F4PGA_DIR_BIN"
echo '::endgroup::'


cd "$F4PGA_DIR_BIN"
ls -lah

