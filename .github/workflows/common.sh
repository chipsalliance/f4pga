#! /bin/bash
# Copyright (C) 2020-2021  The SymbiFlow Authors.
#
# Use of this source code is governed by a ISC-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/ISC
#
# SPDX-License-Identifier:ISC

# Look for location binaries first
export PATH="$HOME/.local-bin/bin:$PATH"

# OS X specific common setup
if [[ "${OS}" == "macOS" ]]; then
	export PATH="/usr/local/opt/ccache/libexec:$PATH"
fi

# Parallel builds!
MAKEFLAGS="-j 2"

function action_fold() {
	if [ "$1" = "start" ]; then
		echo "::group::$2"
		SECONDS=0
	else
		duration=$SECONDS
		echo "::endgroup::"
		printf "${GRAY}took $(($duration / 60)) min $(($duration % 60)) sec.${NC}\n"
	fi
	return 0;
}

function start_section() {
	action_fold start "$1"
	echo -e "${PURPLE}SymbiFlow Yosys Plugins${NC}: - $2${NC}"
	echo -e "${GRAY}-------------------------------------------------------------------${NC}"
}

export -f start_section

function end_section() {
	echo -e "${GRAY}-------------------------------------------------------------------${NC}"
	action_fold end "$1"
}

export -f end_section
