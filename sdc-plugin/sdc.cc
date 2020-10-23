/*
 *  yosys -- Yosys Open SYnthesis Suite
 *
 *  Copyright (C) 2020  The Symbiflow Authors
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */
#include <algorithm>
#include "clocks.h"
#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/rtlil.h"
#include "propagation.h"
#include "set_false_path.h"
#include "set_max_delay.h"
#include "set_clock_groups.h"
#include "sdc_writer.h"

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN

struct ReadSdcCmd : public Frontend {
    ReadSdcCmd() : Frontend("sdc", "Read SDC file") {}

    void help() override {
	log("\n");
	log("    read_sdc <filename>\n");
	log("\n");
	log("Read SDC file.\n");
	log("\n");
    }

    void execute(std::istream*& f, std::string filename,
                 std::vector<std::string> args, RTLIL::Design*) override {
	if (args.size() < 2) {
	    log_cmd_error("Missing script file.\n");
	}
	log("\nReading clock constraints file(SDC)\n\n");
	size_t argidx = 1;
	extra_args(f, filename, args, argidx);
	std::string content{std::istreambuf_iterator<char>(*f),
	                    std::istreambuf_iterator<char>()};
	log("%s\n", content.c_str());
	Tcl_Interp* interp = yosys_get_tcl_interp();
	if (Tcl_EvalFile(interp, args[argidx].c_str()) != TCL_OK) {
	    log_cmd_error("TCL interpreter returned an error: %s\n",
	                  Tcl_GetStringResult(interp));
	}
    }
};

struct WriteSdcCmd : public Backend {
    WriteSdcCmd(SdcWriter& sdc_writer)
        : Backend("sdc", "Write SDC file"), sdc_writer_(sdc_writer) {}

    void help() override {
	log("\n");
	log("    write_sdc <filename>\n");
	log("\n");
	log("Write SDC file.\n");
	log("\n");
    }

    void execute(std::ostream*& f, std::string filename,
                 std::vector<std::string> args, RTLIL::Design* design) override {
	if (args.size() < 2) {
	    log_cmd_error("Missing output file.\n");
	}
	log("\nWriting out clock constraints file(SDC)\n");
	extra_args(f, filename, args, 1);
	sdc_writer_.WriteSdc(design, *f);
    }

    SdcWriter& sdc_writer_;
};

struct CreateClockCmd : public Pass {
    CreateClockCmd()
        : Pass("create_clock", "Create clock object") {}

    void help() override {
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

    void execute(std::vector<std::string> args,
                 RTLIL::Design* design) override {
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
		std::copy_if(edges.begin(), edges.end(), edges.begin(),
		             [](char c) { return c != '{' or c != '}'; });
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
	std::vector<RTLIL::Wire*> selected_wires;
	for (auto module : design->modules()) {
	    if (!design->selected(module)) {
		continue;
	    }
	    for (auto wire : module->wires()) {
		if (design->selected(module, wire)) {
#ifdef SDC_DEBUG
		    log("Selected wire %s\n",
		        RTLIL::unescape_id(wire->name).c_str());
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
	Clock::Add(name, selected_wires, period, rising_edge,
	                 falling_edge);
    }

    void AddWirePrefix(std::vector<std::string>& args, size_t argidx) {
	auto selection_begin = args.begin() + argidx;
	std::transform(selection_begin, args.end(), selection_begin,
	               [](std::string& w) { return "w:" + w; });
    }
};

struct GetClocksCmd : public Pass {
    GetClocksCmd()
        : Pass("get_clocks", "Create clock object") {}

    void help() override {
	log("\n");
	log("    get_clocks\n");
	log("\n");
	log("Returns all clocks in the design.\n");
	log("\n");
    }

    void execute(std::vector<std::string> args,
                 RTLIL::Design* design) override {
	if (args.size() > 1) {
	    log_warning("Command doesn't support arguments, so they will be ignored.\n");
	}
	std::vector<RTLIL::Wire*> clock_wires(Clocks::GetClocks(design));
	if (clock_wires.size() == 0) {
	    log_warning("No clocks found in design\n");
	}
	Tcl_Interp* interp = yosys_get_tcl_interp();
	Tcl_Obj* tcl_list = Tcl_NewListObj(0, NULL);
	for (auto wire : clock_wires) {
	    const char* name = RTLIL::id2cstr(wire->name);
	    Tcl_Obj* name_obj = Tcl_NewStringObj(name, -1);
	    Tcl_ListObjAppendElement(interp, tcl_list, name_obj);
	}
	Tcl_SetObjResult(interp, tcl_list);
    }
};

struct PropagateClocksCmd : public Pass {
    PropagateClocksCmd()
        : Pass("propagate_clocks", "Propagate clock information") {}

    void help() override {
	log("\n");
	log("    propagate_clocks\n");
	log("\n");
	log("Propagate clock information throughout the design.\n");
	log("\n");
    }

    void execute(std::vector<std::string> args,
                 RTLIL::Design* design) override {
	if (args.size() > 1) {
	    log_warning("Command accepts no arguments.\nAll will be ignored.\n");
	}
	if (!design->top_module()) {
	    log_cmd_error("No top module selected\n");
	}

	std::array<std::unique_ptr<Propagation>, 2> passes{
	    std::unique_ptr<Propagation>(
	        new BufferPropagation(design, this)),
	    std::unique_ptr<Propagation>(
	        new ClockDividerPropagation(design, this))};

	log("Perform clock propagation\n");

	for (auto& pass : passes) {
	    pass->Run();
	}
    }
};

class SdcPlugin {
   public:
    SdcPlugin()
        : write_sdc_cmd_(sdc_writer_),
          set_false_path_cmd_(sdc_writer_),
          set_max_delay_cmd_(sdc_writer_),
          set_clock_groups_cmd_(sdc_writer_) {
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
