#!/usr/bin/env bash
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

function contains {
    if [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]]; then
        return 1
    else
        return 0
    fi
}

function random_name {
    local length=$1
    local prefix=$2

    local charset=abcdefghijklmnopqrstuwvxyzABCDEFGHIJKLMNOPQRSTUWVXYZ0123456789

    echo -n $prefix
    for i in $(seq 1 1 $length); do
        echo -n "${charset:RANDOM%${#charset}:1}"
    done
    echo
}

function make_tmp_dir {
    local length=$1
    local prefix=$2

    while [ 1 ]; do
        local dirname=/tmp/`random_name $length $prefix`
        if [[ ! -d $dirname ]]; then
            mkdir $dirname
            echo $dirname
            break
        fi
    done
}

function reserve_tmp_file {
    local length=$1
    local prefix=$2
    local reserved_list=$3
    
    while [ 0 == 0 ]; do
        local fname=`random_name $length $prefix`
        contains $reserved_list $fname
        if [ $? == 0 ]; then
            echo $fname
            break
        fi
    done
}
