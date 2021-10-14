#! /bin/bash
# Copyright (C) 2020-2021  The SymbiFlow Authors.
#
# Use of this source code is governed by a ISC-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/ISC
#
# SPDX-License-Identifier:ISC

set -e

source .github/workflows/common.sh

##########################################################################

# Output status information.
start_section Status
(
    set +e
    set -x
    git status
    git branch -v
    git log -n 5 --graph
    git log --format=oneline -n 20 --graph
)
end_section

##########################################################################

# Update submodules
start_section Submodules
(
    git submodule update --init --recursive
)
end_section

##########################################################################

#Install yosys
start_section Install-Yosys
(
    echo '=========================='
    echo 'Making env with yosys and Surelog'
    echo '=========================='
    if [ "$BUILD_UPSTREAM" = "0" ]
    then
	mkdir -p ~/.local-src
	mkdir -p ~/.local-bin
	cd ~/.local-src
	git clone https://github.com/antmicro/yosys.git -b uhdm-plugin
	cd yosys
	PREFIX=$HOME/.local-bin make -j$(nproc)
	PREFIX=$HOME/.local-bin make install
	cd ..
	git clone --recursive https://github.com/chipsalliance/Surelog.git -b master
	cd Surelog
	cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME/.local-bin -DCMAKE_POSITION_INDEPENDENT_CODE=ON -S . -B build
	cmake --build build -j $(nproc)
	cmake --install build
	cd ../..
    else
	make env
	make enter
    fi
    git clone --recursive https://github.com/chipsalliance/Surelog.git -b master
    cd Surelog
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME/.local-bin -DCMAKE_POSITION_INDEPENDENT_CODE=ON -S . -B build
    cmake --build build -j $(nproc)
    cmake --install build
    cd ../..
    echo $(which yosys)
    echo $(which yosys-config)
    echo $(yosys-config --datdir)
)
end_section

##########################################################################

