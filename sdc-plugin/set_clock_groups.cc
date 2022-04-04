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
#include "set_clock_groups.h"
#include "kernel/log.h"
#include <regex>

USING_YOSYS_NAMESPACE

void SetClockGroups::help()
{
    //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
    log("\n");
    log("   set_clock_groups [-quiet] [-group <args>] [-asynchronous] \n");
    log("\n");
    log("Set exclusive or asynchronous clock groups\n");
    log("\n");
    log("Print the output to stdout too. This is useful when all Yosys is "
        "executed.\n");
    log("\n");
    log("    -quiet\n");
    log("        Don't print the result of the execution to stdout.\n");
    log("\n");
    log("    -group\n");
    log("        List of clocks to be included in the clock group.\n");
    log("\n");
    log("    -asynchronous\n");
    log("       The specified clocks are asynchronous to each other.\n");
    log("\n");
}

void SetClockGroups::execute(std::vector<std::string> args, RTLIL::Design *design)
{
    RTLIL::Module *top_module = design->top_module();
    if (top_module == nullptr) {
        log_cmd_error("No top module detected\n");
    }

    size_t argidx;
    bool is_quiet = false;
    std::vector<ClockGroups::ClockGroup> clock_groups;
    auto clock_groups_relation = ClockGroups::NONE;

    // Parse command arguments
    for (argidx = 1; argidx < args.size(); argidx++) {
        std::string arg = args[argidx];
        if (arg == "-quiet") {
            is_quiet = true;
            continue;
        }

        // Parse clock groups relation: asynchronous, logically_exclusive, physically_exclusive
        auto is_relation_arg = [arg](std::pair<ClockGroups::ClockGroupRelation, std::string> relation) {
            if (arg.substr(1) == relation.second) {
                return true;
            }
            return false;
        };
        auto relation_map_it = std::find_if(ClockGroups::relation_name_map.begin(), ClockGroups::relation_name_map.end(), is_relation_arg);
        if (relation_map_it != ClockGroups::relation_name_map.end()) {
            clock_groups_relation = relation_map_it->first;
            continue;
        }

        if (arg == "-group" and argidx + 1 < args.size()) {
            ClockGroups::ClockGroup clock_group;
            while (argidx + 1 < args.size() and args[argidx + 1][0] != '-') {
                clock_group.push_back(args[++argidx]);
            }
            clock_groups.push_back(clock_group);
            continue;
        }

        if (arg.size() > 0 and arg[0] == '-') {
            log_cmd_error("Unknown option %s.\n", arg.c_str());
        }

        break;
    }

    if (clock_groups.size()) {
        if (!is_quiet) {
            std::string msg = ClockGroups::relation_name_map.at(clock_groups_relation);
            msg += (!msg.empty()) ? " " : "";
            log("Adding %sclock group with following clocks:\n", msg.c_str());
        }
        size_t count(0);
        for (auto &group : clock_groups) {
            sdc_writer_.AddClockGroup(group, clock_groups_relation);
            if (!is_quiet) {
                log("%zu: ", count++);
                for (auto clk : group) {
                    log("%s ", clk.c_str());
                }
                log("\n");
            }
        }
    }
}
