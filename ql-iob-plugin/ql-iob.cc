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

        // Build a map of pad names to entries
        std::unordered_map<std::string, const PinmapParser::Entry> pinmapMap;
        for (auto& entry : pinmapParser.getEntries()) {
            if (entry.count("name") != 0) {
                pinmapMap.emplace(entry.at("name"), entry);
            }
        }

        // A map of IO cell types and their port names that should go to a pad
        std::unordered_map<std::string, std::string> ioCellTypes;

        // TODO
        ioCellTypes.insert(std::make_pair("inpad", "P"));
        ioCellTypes.insert(std::make_pair("outpad", "P"));

        // Check all IO cells
        log("\n");
        log("    type       | instance             | pad        | loc      | cell     \n");
        log("   ------------+----------------------+------------+----------+----------\n");
        for (auto cell : topModule->cells()) {
            auto cellType = RTLIL::unescape_id(cell->type); 

            // Not an IO cell
            if (ioCellTypes.count(cellType) == 0) {
                continue;
            }

            log("    %-10s | %-20s ", cellType.c_str(), cell->name.c_str());

            std::string padName;
            std::string locName;
            std::string cellName;

            // Get connections to the specified port
            std::string port = RTLIL::escape_id(ioCellTypes.at(cellType));
            if (cell->connections().count(port)) {

                // Get the sigspec of the connection
                auto sigspec = cell->connections().at(port);

                // Get the connected wire
                // FIXME: This assumes that the cell is directly connected to a
                // top-level port.
                if (sigspec.is_wire()) {
                    auto wire = sigspec.as_wire();

                    // Has to be top level wire
                    if (wire->port_input || wire->port_output) {

                        // Check if the wire is constrained
                        auto wireName = RTLIL::unescape_id(wire->name);
                        if (constraintMap.count(wireName)) {

                            // Get the constraint
                            auto constraint = constraintMap.at(wireName);

                            // Check if there is an entry in the pinmap for this pad name
                            if (pinmapMap.count(constraint.padName)) {

                                // Get the entry
                                auto entry = pinmapMap.at(constraint.padName);
                                padName = constraint.padName;

                                // Location string
                                if (entry.count("x") && entry.count("y")) {
                                    locName = stringf("X%sY%s", 
                                        entry.at("x").c_str(),
                                        entry.at("y").c_str()
                                    );
                                }

                                // Cell name
                                if (entry.count("cell")) {
                                    cellName = entry.at("cell");
                                }
                            }
                        }
                    }
                }
            }

            log("| %-10s | %-8s | %s\n", 
                padName.c_str(),
                locName.c_str(),
                cellName.c_str()
            );

            // Annotate the cell by setting its parameters
            cell->setParam(RTLIL::escape_id("IO_PAD"),  padName);
            cell->setParam(RTLIL::escape_id("IO_LOC"),  locName);
            cell->setParam(RTLIL::escape_id("IO_TYPE"), cellName);
        }
    }

} QuicklogicIob;

PRIVATE_NAMESPACE_END
