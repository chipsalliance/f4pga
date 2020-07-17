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


void register_in_tcl_interpreter(const std::string& command) {
	Tcl_Interp* interp = yosys_get_tcl_interp();
	std::string tcl_script = stringf("proc %s args { return [yosys %s {*}$args] }", command.c_str(), command.c_str());
	Tcl_Eval(interp, tcl_script.c_str());
}

struct ReadSdc : public Frontend {
	ReadSdc()
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

} ReadSdc;


PRIVATE_NAMESPACE_END
