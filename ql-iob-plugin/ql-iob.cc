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
 *
 */

#include "pcf_parser.hh"
#include "pinmap_parser.hh"

#include "kernel/register.h"
#include "kernel/rtlil.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

void register_in_tcl_interpreter(const std::string& command) {
    Tcl_Interp* interp = yosys_get_tcl_interp();
    std::string tcl_script = stringf("proc %s args { return [yosys %s {*}$args] }", command.c_str(), command.c_str());
    Tcl_Eval(interp, tcl_script.c_str());
}

struct QuicklogicIob : public Pass {

    QuicklogicIob () :
        Pass("quicklogic_iob", "Map IO buffers to cells that correspond to their assigned locations") {
            register_in_tcl_interpreter(pass_name);
        }

    void help() YS_OVERRIDE {
        log("Help!\n");
    }
    
    void execute(std::vector<std::string> a_Args, RTLIL::Design* a_Design) YS_OVERRIDE {
        if (a_Args.size() < 3) {
            log_cmd_error("Usage: quicklogic_iob <PCF file> <pinmap file>");
        }

        // Get the top module of the design
		RTLIL::Module* topModule = a_Design->top_module();
		if (topModule == nullptr) {
			log_cmd_error("No top module detected!\n");
		}

        // Read and parse the PCF file
        log("Loading PCF from '%s'...\n", a_Args[1].c_str());
        auto pcfParser = PcfParser();
        if (!pcfParser.parse(a_Args[1])) {
            log_cmd_error("Failed to parse the PCF file!\n");
        }

        // Read and parse pinmap CSV file
        log("Loading pinmap CSV from '%s'...\n", a_Args[2].c_str());
        auto pinmapParser = PinmapParser();
        if (!pinmapParser.parse(a_Args[2])) {
            log_cmd_error("Failed to parse the pinmap CSV file!\n");
        }

    }

} QuicklogicIob;

PRIVATE_NAMESPACE_END
