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
    wget -qO- https://storage.googleapis.com/symbiflow-arch-defs/artifacts/prod/foss-fpga-tools/symbiflow-arch-defs/continuous/install/535/20220128-000432/symbiflow-arch-defs-install-5fa5e715.tar.xz | tar -xJC $F4PGA_INSTALL_DIR/xc7/install
    wget -qO- https://storage.googleapis.com/symbiflow-arch-defs/artifacts/prod/foss-fpga-tools/symbiflow-arch-defs/continuous/install/535/20220128-000432/symbiflow-arch-defs-xc7a50t_test-5fa5e715.tar.xz | tar -xJC $F4PGA_INSTALL_DIR/xc7/install
  ;;
  eos-s3)
    wget -qO- https://storage.googleapis.com/symbiflow-arch-defs-install/quicklogic-arch-defs-qlf-fc5d8da.tar.gz | tar -xz -C $F4PGA_INSTALL_DIR_FAM
  ;;
esac
echo '::endgroup::'


cd ..


echo '::group::Add f4pga-env'

case "$FPGA_FAM" in
  xc7) F4PGA_DIR_ROOT='install';;
  eos-s3) F4PGA_DIR_ROOT='quicklogic-arch-defs';;
esac

F4PGA_DIR_BIN="$F4PGA_INSTALL_DIR_FAM/$F4PGA_DIR_ROOT"/bin/
cp $(dirname "$0")/../../f4pga-env "$F4PGA_DIR_BIN"

echo '::endgroup::'

echo '::group::🗑️ Remove the wrappers (pre-packaged from arch-defs)'

cd "$F4PGA_DIR_BIN"

case "$FPGA_FAM" in
  xc7)
    rm -vrf \
      env \
      symbiflow_generate_constraints \
      symbiflow_pack \
      symbiflow_place \
      symbiflow_route \
      symbiflow_synth \
      symbiflow_write_bitstream \
      symbiflow_write_fasm \
      vpr_common
  ;;
  eos-s3)
    sed -i 's#${MYPATH}/../share#'"$(./f4pga-env share)"'#' vpr_common
    rm -vrf \
      symbiflow_pack \
      symbiflow_place \
      symbiflow_route \
      symbiflow_write_fasm \
      symbiflow_analysis \
      symbiflow_repack \
      symbiflow_generate_bitstream \
      symbiflow_generate_libfile
  ;;
esac

ls -lah

echo '::endgroup::'
