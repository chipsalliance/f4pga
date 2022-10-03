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
#include "set_max_delay.h"
#include "kernel/log.h"
#include "sdc_writer.h"

USING_YOSYS_NAMESPACE

void SetMaxDelay::help()
{
    //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
    log("\n");
    log("   set_max_delay [-quiet] [-from <arg>] [-to <arg>] \n");
    log("\n");
    log("Specify maximum delay for timing paths\n");
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
}

void SetMaxDelay::execute(std::vector<std::string> args, RTLIL::Design *design)
{
    RTLIL::Module *top_module = design->top_module();
    if (top_module == nullptr) {
        log_cmd_error("No top module detected\n");
    }

    size_t argidx;
    bool is_quiet = false;
    std::string from_pin;
    std::string to_pin;
    float max_delay(0.0);

    // Parse command arguments
    for (argidx = 1; argidx < args.size(); argidx++) {
        std::string arg = args[argidx];
        if (arg == "-quiet") {
            is_quiet = true;
            continue;
        }

        if (arg == "-from" and argidx + 1 < args.size()) {
            from_pin = args[++argidx];
            log("From: %s\n", from_pin.c_str());
            continue;
        }

        if (arg == "-to" and argidx + 1 < args.size()) {
            to_pin = args[++argidx];
            log("To: %s\n", to_pin.c_str());
            continue;
        }

        if (arg.size() > 0 and arg[0] == '-') {
            log_cmd_error("Unknown option %s.\n", arg.c_str());
        }

        max_delay = std::stof(args[argidx]);
    }

    if (!is_quiet) {
        std::string msg = (from_pin.empty()) ? "" : "-from " + from_pin;
        msg += (to_pin.empty()) ? "" : " -to " + to_pin;
        log("Adding max path delay of %f on path %s\n", max_delay, msg.c_str());
    }
    sdc_writer_.SetMaxDelay(TimingPath{.from_pin = from_pin, .to_pin = to_pin, .max_delay = max_delay});
}
