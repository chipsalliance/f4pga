#! /bin/bash

set -e

source .github/workflows/common.sh

##########################################################################

start_section Formatting
make format -j`nproc`
test $(git status --porcelain | wc -l) -eq 0 || { git diff; false; }
end_section

##########################################################################
