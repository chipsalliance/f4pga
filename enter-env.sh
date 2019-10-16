#!/bin/bash

if [ ! -n "${BASH_VERSION}" ]; then
    echo "This script has to be sourced in bash!"
    exit 1
fi

[[ "${BASH_SOURCE[0]}" != "${0}" ]] && SOURCED=1 || SOURCED=0
if [ ${SOURCED} == 0 ]; then
    echo "This script has to be sourced!"
    exit 1
fi

CONDA_DIR=${PWD}/build/conda
CONDA_DIR_NAME=SymbiFlow-docs

export PATH="${CONDA_DIR}/bin:$PATH"

# Use Conda hook for user shell
SHELL_NAME=`basename $SHELL`
CONDA_HOOK_COMMAND="${CONDA_DIR}/bin/conda shell.${SHELL_NAME} hook"
eval "$(${CONDA_HOOK_COMMAND})"

conda activate ${CONDA_DIR_NAME}
