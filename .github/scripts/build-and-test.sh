#! /bin/bash
# Copyright 2020-2022 F4PGA Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

set -e

source .github/scripts/common.sh

##########################################################################

start_section Building

export CXXFLAGS=-Werror
make -C yosys-plugins UHDM_INSTALL_DIR=`pwd`/yosys-plugins/env/conda/envs/yosys-plugins/ plugins -j`nproc`
unset CXXFLAGS

end_section

##########################################################################

start_section Installing
make -C yosys-plugins install -j`nproc`
end_section

##########################################################################

start_section Testing
make -C yosys-plugins test -j`nproc`
end_section

##########################################################################

start_section Cleanup
make -C yosys-plugins plugins_clean -j`nproc`
end_section

##########################################################################
