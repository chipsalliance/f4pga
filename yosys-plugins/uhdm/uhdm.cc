/*
 * Copyright 2020-2022 F4PGA Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */
#include "kernel/log.h"

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN

struct UhdmDummy {
    UhdmDummy()
    {
        log("\n");
        log("!! DEPRECATION WARNING !!\n");
        log("\n");
        log("The uhdm plugin has been renamed to systemverilog.\n");
        log("Loading the systemverilog plugin...\n");

        std::vector<std::string> plugin_aliases;
        load_plugin("systemverilog", plugin_aliases);
    }
} UhdmDummy;

PRIVATE_NAMESPACE_END
