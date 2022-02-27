#!/usr/bin/env bash


echo '::group::Install dependencies'
sudo apt update -y
sudo apt install -y git wget xz-utils
echo '::endgroup::'


echo '::group::Clone f4pga-examples'
git clone --recurse-submodules https://github.com/chipsalliance/f4pga-examples
cd f4pga-examples
echo '::endgroup::'


F4PGA_FAM=${F4PGA_FAM:=xc7}

echo '::group::Install Miniconda3'
wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O conda_installer.sh

F4PGA_INSTALL_DIR_FAM="$F4PGA_INSTALL_DIR/$F4PGA_FAM"

bash conda_installer.sh -u -b -p "$F4PGA_INSTALL_DIR_FAM"/conda
source "$F4PGA_INSTALL_DIR_FAM"/conda/etc/profile.d/conda.sh
echo '::endgroup::'


echo '::group::Create environment'
conda env create -f "$F4PGA_FAM"/environment.yml
echo '::endgroup::'


echo '::group::Install arch-defs'
case "$F4PGA_FAM" in
  xc7)
    mkdir -p "$F4PGA_INSTALL_DIR_FAM"/install
    wget -qO- https://storage.googleapis.com/symbiflow-arch-defs/artifacts/prod/foss-fpga-tools/symbiflow-arch-defs/continuous/install/535/20220128-000432/symbiflow-arch-defs-install-5fa5e715.tar.xz | tar -xJC $F4PGA_INSTALL_DIR/xc7/install
    wget -qO- https://storage.googleapis.com/symbiflow-arch-defs/artifacts/prod/foss-fpga-tools/symbiflow-arch-defs/continuous/install/535/20220128-000432/symbiflow-arch-defs-xc7a50t_test-5fa5e715.tar.xz | tar -xJC $F4PGA_INSTALL_DIR/xc7/install
  ;;
  eos-s3)
    wget -qO- https://storage.googleapis.com/symbiflow-arch-defs-install/quicklogic-arch-defs-63c3d8f9.tar.gz | tar -xz -C $F4PGA_INSTALL_DIR_FAM
  ;;
esac
echo '::endgroup::'
