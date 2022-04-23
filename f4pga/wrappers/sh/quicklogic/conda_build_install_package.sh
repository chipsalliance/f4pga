#!/bin/bash
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

echo -e "\e[1;34mInstallation starting for conda based symbiflow\e[0m"
echo -e "\e[1;34mQuickLogic Corporation\e[0m"

if [ -z "$INSTALL_DIR" ]
then
	echo -e "\e[1;31m\$INSTALL_DIR is not set, please set and then proceed!\e[0m"
	echo -e "\e[1;31mExample: \"export INSTALL_DIR=/<custom_location>\". \e[0m"
	exit 0
elif [ -d "$INSTALL_DIR/conda" ]; then
	echo -e "\e[1;32m $INSTALL_DIR/conda already exists, please clean up and re-install ! \e[0m"
	exit 0
else
	echo -e "\e[1;32m\$INSTALL_DIR is set to $INSTALL_DIR ! \e[0m"
fi

mkdir -p $INSTALL_DIR

wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O conda_installer.sh
bash conda_installer.sh -b -p $INSTALL_DIR/conda && rm conda_installer.sh
source "$INSTALL_DIR/conda/etc/profile.d/conda.sh"
echo "include-system-site-packages=false" >> $INSTALL_DIR/conda/pyvenv.cfg
CONDA_FLAGS="-y --override-channels -c defaults -c conda-forge"
conda update $CONDA_FLAGS -q conda
curl $(curl https://storage.googleapis.com/symbiflow-arch-defs-install/latest-qlf) > arch.tar.gz
tar -C $INSTALL_DIR -xvf arch.tar.gz && rm arch.tar.gz
conda install $CONDA_FLAGS -c litex-hub/label/main yosys="0.9_5266_g0fb4224e 20210301_104249_py37"
conda install $CONDA_FLAGS -c litex-hub/label/main symbiflow-yosys-plugins="1.0.0_7_338_g93157fb=20210507_125510"
conda install $CONDA_FLAGS -c litex-hub/label/main vtr-optimized="8.0.0_3614_gb3b34e77a 20210507_125510"
conda install $CONDA_FLAGS -c litex-hub iverilog
conda install $CONDA_FLAGS -c tfors gtkwave
conda install $CONDA_FLAGS make lxml simplejson intervaltree git pip
conda activate
pip install python-constraint
pip install serial
pip install git+https://github.com/QuickLogic-Corp/ql_fasm@e5d0915
conda deactivate
setup_file=$INSTALL_DIR/setup.sh
echo "export INSTALL_DIR=$INSTALL_DIR" >$setup_file
chmod 755 $setup_file

# Adding symbiflow toolchain binaries to PATH
echo "export PATH=\"\$INSTALL_DIR/quicklogic-arch-defs/bin:\$INSTALL_DIR/quicklogic-arch-defs/bin/python:\$PATH\"" >>$setup_file
echo "source \"\$INSTALL_DIR/conda/etc/profile.d/conda.sh\"" >>$setup_file
echo "conda activate" >>$setup_file
