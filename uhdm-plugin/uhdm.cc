/*
 * Copyright (C) 2019-2022 The SymbiFlow Authors
 *
 * Use of this source code is governed by a ISC-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/ISC
 *
 * SPDX-License-Identifier: ISC
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
