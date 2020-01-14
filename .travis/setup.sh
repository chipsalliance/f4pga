#! /bin/bash

set -e

source .travis/common.sh

##########################################################################

# Output status information.
(
	set +e
	set -x
	git status
	git branch -v
	git log -n 5 --graph
	git log --format=oneline -n 20 --graph
)
echo
echo -en 'travis_fold:end:before_install.git\\r'
echo

##########################################################################

#Install yosys
(
        if [ ! -e ~/.local-bin/bin/yosys ]; then
                echo
                echo 'Building yosys...' && echo -en 'travis_fold:start:before_install.yosys\\r'
                echo
                mkdir -p ~/.local-src
                mkdir -p ~/.local-bin
                cd ~/.local-src
                git clone https://github.com/SymbiFlow/yosys.git -b master+wip
                cd yosys
                PREFIX=$HOME/.local-bin make -j$(nproc)
                PREFIX=$HOME/.local-bin make install
                echo $(which yosys)
                echo $(which yosys-config)
                echo $(yosys-config --datdir)
                echo
                echo -en 'travis_fold:end:before_install.yosys\\r'
                echo
        fi
)

##########################################################################

