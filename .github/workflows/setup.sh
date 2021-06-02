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
    if [ ! -e ~/.local-bin/bin/yosys ]; then
        echo '=========================='
        echo 'Building yosys'
        echo '=========================='
        mkdir -p ~/.local-src
        mkdir -p ~/.local-bin
        cd ~/.local-src
        git clone https://github.com/SymbiFlow/yosys.git -b master+wip
        cd yosys
        make config-gcc # Build Yosys using GCC
        PREFIX=$HOME/.local-bin make -j$(nproc)
        PREFIX=$HOME/.local-bin make install
        echo $(which yosys)
        echo $(which yosys-config)
        echo $(yosys-config --datdir)
    fi
)
end_section

##########################################################################

