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
		m_topModule = a_Design->top_module();
		if (m_topModule == nullptr) {
			log_cmd_error("No top module detected!\n");
		}

        // Read and parse the PCF file
        log("Loading PCF from '%s'...\n", a_Args[1].c_str());
        auto pcfParser = PcfParser();
        if (!pcfParser.parse(a_Args[1])) {
            log_cmd_error("Failed to parse the PCF file!\n");
        }

        // Build a map of net names to constraints
        std::unordered_map<std::string, const PcfParser::Constraint> constraintMap;
        for (auto& constraint : pcfParser.getConstraints()) {
            if (constraintMap.count(constraint.netName) != 0) {
                log_cmd_error("The net '%s' is constrained twice!", constraint.netName.c_str());
            }
            constraintMap.emplace(constraint.netName, constraint);
        }

        // Read and parse pinmap CSV file
        log("Loading pinmap CSV from '%s'...\n", a_Args[2].c_str());
        auto pinmapParser = PinmapParser();
        if (!pinmapParser.parse(a_Args[2])) {
            log_cmd_error("Failed to parse the pinmap CSV file!\n");
        }

        // A map of IO cell types and their port names that should go to a pad
        std::unordered_map<std::string, std::string> ioCellTypes;

        // TODO
        ioCellTypes.insert(std::make_pair("inpad", "P"));
        ioCellTypes.insert(std::make_pair("outpad", "P"));

        // Check all IO cells
        for (auto cell : m_topModule->cells()) {
            auto cellType = RTLIL::unescape_id(cell->type); 

            // No an IO cell
            if (ioCellTypes.count(cellType) == 0) {
                continue;
            }

            log("   %-16s %-40s ", cellType.c_str(), cell->name.c_str());

            // Get connections to the specified port
            std::string port = RTLIL::escape_id(ioCellTypes.at(cellType));
            if (cell->connections().count(port) == 0) {
                log(" Port '%s' not found!\n", port.c_str());
                continue;
            }

            // Get the sigspec of the connection
            auto sigspec = cell->connections().at(port);

            // Get the connected wire
            if (!sigspec.is_wire()) {
                log(" Couldn't determine connection\n");
                continue;
            }
            auto wire = sigspec.as_wire();

            // Has to be top level wire
            if (!wire->port_input && !wire->port_output) {
                log(" No top-level port!\n");
                continue;
            }

            // Check if the wire is constrained
            auto wireName = RTLIL::unescape_id(wire->name);
            if (constraintMap.count(wireName) == 0) {
                log("\n");
                continue;
            }

            // Get the constraint
            auto constraint = constraintMap.at(wireName);
            log("%s\n", constraint.padName.c_str());
        }

//        log("%zu connections\n", m_topModule->connections().size());

//        for (auto cell : m_topModule->cells()) {
//            log("'%s' '%s' %zu\n", cell->name.c_str(), cell->type.c_str(), cell->connections().size());
//            for (auto c : cell->connections()) {
//                log(" '%s'\n", c.first.c_str());
//            }
//        }

/*        // Get top-level wires
        for (auto wire : m_topModule->wires()) {

            // Not a top-level
		    if (!wire->port_input && !wire->port_output) {
                continue;
            }

            log("'%s'\n", wire->name.c_str());
            //getConnectedCell(wire, 0);
        }*/
    }

    // ..............................................................

    RTLIL::Module* m_topModule = nullptr;

    // ..............................................................

    RTLIL::Module* getConnectedCell(RTLIL::Wire* wire, size_t bit = 0) {

        RTLIL::Module* module = wire->module;

        log("'%s' %d\n", wire->name.c_str(), bit);
        for (auto connection : m_topModule->connections_) {
            log("k");
			auto dst_sig = connection.first;
			auto src_sig = connection.second;

            // Go down
            if (dst_sig.is_chunk()) {
				auto chunk = dst_sig.as_chunk();
                if (chunk.wire) {
                    log(" '%s'\n", chunk.wire->name.c_str());
                }
                log("%d\n", chunk.width);
            }
            
            if (dst_sig.is_wire()) {
                auto w = dst_sig.as_wire();
                log(" '%s'\n",w->name.c_str());
            }

/*			if (dst_sig.is_chunk()) {
				auto chunk = dst_sig.as_chunk();

				if (chunk.wire) {

					if (chunk.wire->name != wire->name) {
						continue;
					}
					if (bit < chunk.offset || bit >= (chunk.offset + chunk.width)) {
						continue;
					}

					auto src_wires = src_sig.to_sigbit_vector();
					auto src_wire_sigbit = src_wires.at(bit - chunk.offset);
					if (src_wire_sigbit.wire) {
                        log(" '%s'\n", src_wire_sigbit.wire->name.c_str());
                    }
                }
            }*/
        }

        return nullptr;
    }

} QuicklogicIob;

PRIVATE_NAMESPACE_END
