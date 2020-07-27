/*
 *  yosys -- Yosys Open SYnthesis Suite
 *
 *  Copyright (C) 2012  Clifford Wolf <clifford@clifford.at>
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
#include "kernel/register.h"
#include "kernel/rtlil.h"
#include "kernel/log.h"

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN

struct ReadSdcCmd : public Frontend {
	ReadSdcCmd()
	       	: Frontend("sdc", "Read SDC file"){}

	void help() override {
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
		log("\n");
		log("    read_sdc <filename>\n");
		log("\n");
		log("Read SDC file.\n");
		log("\n");
	}

	void execute(std::istream *&f, std::string filename, std::vector<std::string> args, RTLIL::Design*) override {
                if (args.size() < 2) {
                        log_cmd_error("Missing script file.\n");
		}
		size_t argidx = 1;
		extra_args(f, filename, args, argidx);
		std::string content{std::istreambuf_iterator<char>(*f), std::istreambuf_iterator<char>()};
		log("%s\n", content.c_str());
		Tcl_Interp* interp = yosys_get_tcl_interp();
                if (Tcl_EvalFile(interp, args[argidx].c_str()) != TCL_OK) {
                        log_cmd_error("TCL interpreter returned an error: %s\n", Tcl_GetStringResult(interp));
		}
	}
};

using Clocks = std::vector<RTLIL::Wire*>;

struct CreateClockCmd : public Pass {
	CreateClockCmd(Clocks& clocks)
		: Pass("create_clock", "Create clock object")
       		, clocks_(clocks)
		{}

	void help() override
	{
		log("\n");
		log("    create_clock [ -name clock_name ] -period period_value [-waveform <edge_list>] <target>\n");
		log("Define a clock.\n");
	        log("If name is not specified then the name of the first target is selected as the clock's name.\n");
		log("Period is expressed in nanoseconds.\n");
		log("The waveform option specifies the duty cycle (the rising a falling edges) of the clock.\n");
		log("It is specified as a list of two elements/time values: the first rising edge and the next falling edge.\n");
		log("\n");
	}

        void execute(std::vector<std::string> args, RTLIL::Design *design) override
        {
                size_t argidx;
		std::string name;
		float rising_edge(0);
		float falling_edge(0);
		float period(0);
                for (argidx = 1; argidx < args.size(); argidx++)
                {
                        std::string arg = args[argidx];
                        if (arg == "-name" && argidx + 1 < args.size()) {
                                name = args[++argidx];
                                continue;
                        }
                        if (arg == "-period" && argidx + 1 < args.size()) {
                                period = std::stof(args[++argidx]);
                                continue;
                        }
                        if (arg == "-waveform" && argidx + 2 < args.size()) {
                                rising_edge = std::stof(args[++argidx]);
                                falling_edge = std::stof(args[++argidx]);
                                continue;
                        }
			break;
		}
		// Add "w:" prefix to selection arguments to enforce wire object selection
		AddWirePrefix(args, argidx);
		extra_args(args, argidx, design);
		// If clock name is not specified then take the name of the first target
		for (auto module : design->modules()) {
			if (!design->selected(module)) {
				continue;
			}
			for (auto wire : module->wires()) {
				if (design->selected(module, wire)) {
					log("Selected wire %s\n", wire->name.c_str());
					clocks_.push_back(wire);
				}
			}
		}
		if (name.empty()) {
			name = clocks_.at(0)->name.str();
		}

		log("Created clock %s with period %f, waveform %f,%f\n", name.c_str(), period, rising_edge, falling_edge);
	}

	void AddWirePrefix(std::vector<std::string>& args, size_t argidx) {
		auto selection_begin = args.begin() + argidx;
		std::transform(selection_begin, args.end(), selection_begin, [](std::string& w) {return "w:" + w;});
	}

	Clocks& clocks_;
};

class SdcPlugin {
	public:
		SdcPlugin()
		: create_clock_cmd_(clocks_)
		{log("Loaded SDC plugin\n");}

		ReadSdcCmd read_sdc_cmd_;
		CreateClockCmd create_clock_cmd_;

	private:
		Clocks clocks_;
} SdcPlugin;




PRIVATE_NAMESPACE_END
