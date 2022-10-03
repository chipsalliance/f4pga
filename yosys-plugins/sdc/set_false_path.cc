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
#include "set_false_path.h"
#include "kernel/log.h"
#include "sdc_writer.h"
#include <regex>

USING_YOSYS_NAMESPACE

void SetFalsePath::help()
{
    //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
    log("\n");
    log("   set_false_path [-quiet] [-from <net_name>] [-to <net_name>] \n");
    log("\n");
    log("Set false path on the specified net\n");
    log("\n");
    log("Print the output to stdout too. This is useful when all Yosys is "
        "executed.\n");
    log("\n");
    log("    -quiet\n");
    log("        Don't print the result of the execution to stdout.\n");
    log("\n");
    log("    -from\n");
    log("        List of start points or clocks.\n");
    log("\n");
    log("    -to\n");
    log("        List of end points or clocks.\n");
    log("\n");
    log("    -through\n");
    log("        List of through points or clocks.\n");
    log("\n");
}

void SetFalsePath::execute(std::vector<std::string> args, RTLIL::Design *design)
{
    RTLIL::Module *top_module = design->top_module();
    if (top_module == nullptr) {
        log_cmd_error("No top module detected\n");
    }

    size_t argidx;
    bool is_quiet = false;
    std::string from_pin;
    std::string to_pin;
    std::string through_pin;

    // Parse command arguments
    for (argidx = 1; argidx < args.size(); argidx++) {
        std::string arg = args[argidx];
        if (arg == "-quiet") {
            is_quiet = true;
            continue;
        }

        if (arg == "-from" and argidx + 1 < args.size()) {
            from_pin = args[++argidx];
            continue;
        }

        if (arg == "-to" and argidx + 1 < args.size()) {
            to_pin = args[++argidx];
            continue;
        }

        if (arg == "-through" and argidx + 1 < args.size()) {
            through_pin = args[++argidx];
            continue;
        }

        if (arg.size() > 0 and arg[0] == '-') {
            log_cmd_error("Unknown option %s.\n", arg.c_str());
        }

        break;
    }
    if (!is_quiet) {
        std::string msg = (from_pin.empty()) ? "" : "-from " + from_pin;
        msg += (through_pin.empty()) ? "" : " -through " + through_pin;
        msg += (to_pin.empty()) ? "" : " -to " + to_pin;
        log("Adding false path %s\n", msg.c_str());
    }
    sdc_writer_.AddFalsePath(FalsePath{.from_pin = from_pin, .to_pin = to_pin, .through_pin = through_pin});
}
