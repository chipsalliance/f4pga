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
#include <algorithm>
#include <array>

#include "clocks.h"
#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/rtlil.h"
#include "propagation.h"
#include "sdc_writer.h"
#include "set_clock_groups.h"
#include "set_false_path.h"
#include "set_max_delay.h"

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN

struct ReadSdcCmd : public Frontend {
    ReadSdcCmd() : Frontend("sdc", "Read SDC file") {}

    void help() override
    {
        log("\n");
        log("    read_sdc <filename>\n");
        log("\n");
        log("Read SDC file.\n");
        log("\n");
    }

    void execute(std::istream *&f, std::string filename, std::vector<std::string> args, RTLIL::Design *) override
    {
        if (args.size() < 2) {
            log_cmd_error("Missing script file.\n");
        }
        log("\nReading clock constraints file(SDC)\n\n");
        size_t argidx = 1;
        extra_args(f, filename, args, argidx);
        std::string content{std::istreambuf_iterator<char>(*f), std::istreambuf_iterator<char>()};
        log("%s\n", content.c_str());
        Tcl_Interp *interp = yosys_get_tcl_interp();
        if (Tcl_EvalFile(interp, args[argidx].c_str()) != TCL_OK) {
            log_cmd_error("TCL interpreter returned an error: %s\n", Tcl_GetStringResult(interp));
        }
    }
};

struct WriteSdcCmd : public Backend {
    WriteSdcCmd(SdcWriter &sdc_writer) : Backend("sdc", "Write SDC file"), sdc_writer_(sdc_writer) {}

    void help() override
    {
        log("\n");
        log("    write_sdc [-include_propagated_clocks] <filename>\n");
        log("\n");
        log("Write SDC file.\n");
        log("\n");
        log("    -include_propagated_clocks\n");
        log("       Write out all propagated clocks");
        log("\n");
    }

    void execute(std::ostream *&f, std::string filename, std::vector<std::string> args, RTLIL::Design *design) override
    {
        size_t argidx;
        bool include_propagated = false;
        if (args.size() < 2) {
            log_cmd_error("Missing output file.\n");
        }
        for (argidx = 1; argidx < args.size(); argidx++) {
            std::string arg = args[argidx];
            if (arg == "-include_propagated_clocks" && argidx + 1 < args.size()) {
                include_propagated = true;
                continue;
            }
            break;
        }
        log("\nWriting out clock constraints file(SDC)\n");
        extra_args(f, filename, args, argidx);
        sdc_writer_.WriteSdc(design, *f, include_propagated);
    }

    SdcWriter &sdc_writer_;
};

struct CreateClockCmd : public Pass {
    CreateClockCmd() : Pass("create_clock", "Create clock object") {}

    void help() override
    {
        log("\n");
        log("    create_clock [ -name clock_name ] -period period_value "
            "[-waveform <edge_list>] <target>\n");
        log("Define a clock.\n");
        log("If name is not specified then the name of the first target is "
            "selected as the clock's name.\n");
        log("Period is expressed in nanoseconds.\n");
        log("The waveform option specifies the duty cycle (the rising a "
            "falling edges) of the clock.\n");
        log("It is specified as a list of two elements/time values: the first "
            "rising edge and the next falling edge.\n");
        log("\n");
    }

    void execute(std::vector<std::string> args, RTLIL::Design *design) override
    {
        size_t argidx;
        std::string name;
        bool is_waveform_specified(false);
        float rising_edge(0);
        float falling_edge(0);
        float period(0);
        if (args.size() < 4) {
            log_cmd_error("Incorrect number of arguments\n");
        }
        for (argidx = 1; argidx < args.size(); argidx++) {
            std::string arg = args[argidx];
            if (arg == "-add" && argidx + 1 < args.size()) {
                continue;
            }
            if (arg == "-name" && argidx + 1 < args.size()) {
                name = args[++argidx];
                continue;
            }
            if (arg == "-period" && argidx + 1 < args.size()) {
                period = std::stof(args[++argidx]);
                continue;
            }
            if (arg == "-waveform" && argidx + 1 < args.size()) {
                std::string edges(args[++argidx]);
                std::copy_if(edges.begin(), edges.end(), edges.begin(), [](char c) { return c != '{' or c != '}'; });
                std::stringstream ss(edges);
                ss >> rising_edge >> falling_edge;
                is_waveform_specified = true;
                continue;
            }
            break;
        }
        if (period <= 0) {
            log_cmd_error("Incorrect period value\n");
        }
        // Add "w:" prefix to selection arguments to enforce wire object
        // selection
        AddWirePrefix(args, argidx);
        extra_args(args, argidx, design);
        // If clock name is not specified then take the name of the first target
        std::vector<RTLIL::Wire *> selected_wires;
        for (auto module : design->modules()) {
            if (!design->selected(module)) {
                continue;
            }
            for (auto wire : module->wires()) {
                if (design->selected(module, wire)) {
#ifdef SDC_DEBUG
                    log("Selected wire %s\n", RTLIL::unescape_id(wire->name).c_str());
#endif
                    selected_wires.push_back(wire);
                }
            }
        }
        if (selected_wires.size() == 0) {
            log_cmd_error("Target selection is empty\n");
        }
        if (name.empty()) {
            name = RTLIL::unescape_id(selected_wires.at(0)->name);
        }
        if (!is_waveform_specified) {
            rising_edge = 0;
            falling_edge = period / 2;
        }
        Clock::Add(name, selected_wires, period, rising_edge, falling_edge, Clock::EXPLICIT);
    }

    void AddWirePrefix(std::vector<std::string> &args, size_t argidx)
    {
        auto selection_begin = args.begin() + argidx;
        std::transform(selection_begin, args.end(), selection_begin, [](std::string &w) { return "w:" + w; });
    }
};

struct GetClocksCmd : public Pass {
    GetClocksCmd() : Pass("get_clocks", "Create clock object") {}

    void help() override
    {
        log("\n");
        log("    get_clocks [-include_generated_clocks] [-of <nets>] "
            "[<patterns>]\n");
        log("\n");
        log("Returns all clocks in the design.\n");
        log("\n");
        log("    -include_generated_clocks\n");
        log("        Include auto-generated clocks.\n");
        log("\n");
        log("    -of\n");
        log("        Get clocks of these nets.\n");
        log("\n");
        log("    <pattern>\n");
        log("        Pattern of clock names. Default are all clocks in the "
            "design.\n");
        log("\n");
    }

    std::vector<std::string> extract_list(const std::string &args)
    {
        std::vector<std::string> port_list;
        std::stringstream ss(args);
        std::istream_iterator<std::string> begin(ss);
        std::istream_iterator<std::string> end;
        std::copy(begin, end, std::back_inserter(port_list));
        return port_list;
    }

    void execute(std::vector<std::string> args, RTLIL::Design *design) override
    {

        // Parse command arguments
        bool include_generated_clocks(false);
        std::vector<std::string> clocks_nets;
        size_t argidx(0);

        // Parse command switches
        for (argidx = 1; argidx < args.size(); argidx++) {
            std::string arg = args[argidx];
            if (arg == "-include_generated_clocks") {
                include_generated_clocks = true;
                continue;
            }
            if (arg == "-of" and argidx + 1 < args.size()) {
                clocks_nets = extract_list(args[++argidx]);
#ifdef SDC_DEBUG
                for (auto clock_net : clocks_nets) {
                    log("Clock filter %s\n", clock_net.c_str());
                }
#endif
                continue;
            }
            if (arg.size() > 0 and arg[0] == '-') {
                log_cmd_error("Unknown option %s.\n", arg.c_str());
            }

            break;
        }

        // Parse object patterns
        std::vector<std::string> clocks_list(args.begin() + argidx, args.end());

        // Fetch clocks in the design
        std::map<std::string, RTLIL::Wire *> clocks(Clocks::GetClocks(design));
        if (clocks.size() == 0) {
            log_warning("No clocks found in design\n");
        }

        // Extract clocks into tcl list
        Tcl_Interp *interp = yosys_get_tcl_interp();
        Tcl_Obj *tcl_list = Tcl_NewListObj(0, NULL);
        for (auto &clock : clocks) {
            // Skip propagated clocks (i.e. clock wires with the same parameters
            // as the master clocks they originate from
            if (Clock::IsPropagated(clock.second)) {
                continue;
            }
            // Skip generated clocks if -include_generated_clocks is not specified
            if (Clock::IsGenerated(clock.second) and !include_generated_clocks) {
                continue;
            }
            // Check if clock name is in the list of design clocks
            if (clocks_list.size() > 0 and std::find(clocks_list.begin(), clocks_list.end(), clock.first) == clocks_list.end()) {
                continue;
            }
            // Check if clock wire is in the -of list
            if (clocks_nets.size() > 0 and std::find(clocks_nets.begin(), clocks_nets.end(), Clock::WireName(clock.second)) == clocks_nets.end()) {
                continue;
            }
            auto &wire = clock.second;
            const char *name = RTLIL::id2cstr(wire->name);
            Tcl_Obj *name_obj = Tcl_NewStringObj(name, -1);
            Tcl_ListObjAppendElement(interp, tcl_list, name_obj);
        }
        Tcl_SetObjResult(interp, tcl_list);
    }
};

struct PropagateClocksCmd : public Pass {
    PropagateClocksCmd() : Pass("propagate_clocks", "Propagate clock information") {}

    void help() override
    {
        log("\n");
        log("    propagate_clocks\n");
        log("\n");
        log("Propagate clock information throughout the design.\n");
        log("\n");
    }

    void execute(std::vector<std::string> args, RTLIL::Design *design) override
    {
        if (args.size() > 1) {
            log_warning("Command accepts no arguments.\nAll will be ignored.\n");
        }
        if (!design->top_module()) {
            log_cmd_error("No top module selected\n");
        }

        std::array<std::unique_ptr<Propagation>, 2> passes{std::unique_ptr<Propagation>(new BufferPropagation(design, this)),
                                                           std::unique_ptr<Propagation>(new ClockDividerPropagation(design, this))};

        log("Perform clock propagation\n");

        for (auto &pass : passes) {
            pass->Run();
        }

        Clocks::UpdateAbc9DelayTarget(design);
    }
};

class SdcPlugin
{
  public:
    SdcPlugin() : write_sdc_cmd_(sdc_writer_), set_false_path_cmd_(sdc_writer_), set_max_delay_cmd_(sdc_writer_), set_clock_groups_cmd_(sdc_writer_)
    {
        log("Loaded SDC plugin\n");
    }

    ReadSdcCmd read_sdc_cmd_;
    WriteSdcCmd write_sdc_cmd_;
    CreateClockCmd create_clock_cmd_;
    GetClocksCmd get_clocks_cmd_;
    PropagateClocksCmd propagate_clocks_cmd_;
    SetFalsePath set_false_path_cmd_;
    SetMaxDelay set_max_delay_cmd_;
    SetClockGroups set_clock_groups_cmd_;

  private:
    SdcWriter sdc_writer_;
} SdcPlugin;

PRIVATE_NAMESPACE_END
