/*
 *  yosys -- Yosys Open SYnthesis Suite
 *
 *  Copyright (C) 2012  Clifford Wolf <clifford@clifford.at>
 *  Copyright (C) 2019  The Symbiflow Authors
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
 *  ---
 *
 *   XDC commands
 *
 *   This plugin operates on the existing design and modifies its structure
 *   based on the content of the XDC (Xilinx Design Constraints) file.
 *   Since the XDC file consists of Tcl commands it is read using Yosys's
 *   Tcl interpreter and processed by the new XDC commands imported to the
 *   Tcl interpreter.
 */
#include <cassert>
#include "kernel/register.h"
#include "kernel/rtlil.h"
#include "kernel/log.h"
#include "libs/json11/json11.hpp"
#include "../bank_tiles.h"

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN

static bool isInputPort(RTLIL::Wire* wire) {
	return wire->port_input;
}
static bool isOutputPort(RTLIL::Wire* wire) {
	return wire->port_output;
}

enum class SetPropertyOptions { INTERNAL_VREF, IOSTANDARD, SLEW, DRIVE, IN_TERM };

const std::unordered_map<std::string, SetPropertyOptions> set_property_options_map  = {
	{"INTERNAL_VREF", SetPropertyOptions::INTERNAL_VREF},
	{"IOSTANDARD", SetPropertyOptions::IOSTANDARD},
	{"SLEW", SetPropertyOptions::SLEW},
	{"DRIVE", SetPropertyOptions::DRIVE},
	{"IN_TERM", SetPropertyOptions::IN_TERM}
};

void register_in_tcl_interpreter(const std::string& command) {
	Tcl_Interp* interp = yosys_get_tcl_interp();
	std::string tcl_script = stringf("proc %s args { return [yosys %s {*}$args] }", command.c_str(), command.c_str());
	Tcl_Eval(interp, tcl_script.c_str());
}

struct GetPorts : public Pass {
	GetPorts() : Pass("get_ports", "Print matching ports") {
		register_in_tcl_interpreter(pass_name);
	}

	void help() YS_OVERRIDE
	{
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
		log("\n");
		log("   get_ports <port_name> \n");
		log("\n");
		log("Get matching ports\n");
		log("\n");
		log("Print the output to stdout too. This is useful when all Yosys is executed\n");
		log("\n");
	}

	void execute(std::vector<std::string> args, RTLIL::Design* design) YS_OVERRIDE
	{
		if (args.size() < 2) {
			log_cmd_error("No port specified.\n");
		}
		RTLIL::Module* top_module = design->top_module();
		if (top_module == nullptr) {
			log_cmd_error("No top module detected\n");
		}
		// TODO handle more than one port
		port_name = args.at(1);
		char port[128];
		int bit(0);
		std::string port_signal(port_name);
		if (sscanf(port_name.c_str(), "%[^[][%d]", port, &bit) == 2) {
			port_signal = std::string(port);
		}

		RTLIL::IdString port_id(RTLIL::escape_id(port_signal.c_str()));
		if (auto wire = top_module->wire(port_id)) {
			if (isInputPort(wire) || isOutputPort(wire)) {
				Tcl_Interp *interp = yosys_get_tcl_interp();
				Tcl_SetResult(interp, const_cast<char*>(port_name.c_str()), NULL);
				log("Found port %s\n", port_name.c_str());
				return;
			}
		}
		log_warning("Couldn't find port %s\n", port_name.c_str());
	}
	std::string port_name;
};

struct GetIOBanks : public Pass {
	GetIOBanks(std::function<const BankTilesMap&()> get_bank_tiles)
		: Pass("get_iobanks", "Set IO Bank number")
		, get_bank_tiles(get_bank_tiles) {
		register_in_tcl_interpreter(pass_name);
	}

	void help() YS_OVERRIDE	{
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
		log("\n");
		log("   get_iobanks <bank_number>\n");
		log("\n");
		log("Get IO Bank number\n");
		log("\n");
	}

	void execute(std::vector<std::string> args, RTLIL::Design* ) YS_OVERRIDE {
		if (args.size() < 2) {
			log_cmd_error("%s: Missing bank number.\n", pass_name.c_str());
		}
		auto bank_tiles = get_bank_tiles();
		if (bank_tiles.count(std::atoi(args[1].c_str())) == 0) {
			log_cmd_error("%s:Bank number %s is not present in the target device.\n", args[1].c_str(), pass_name.c_str());
		}

                Tcl_Interp *interp = yosys_get_tcl_interp();
		Tcl_SetResult(interp, const_cast<char*>(args[1].c_str()), NULL);
		log("%s\n", args[1].c_str());
	}

	std::function<const BankTilesMap&()> get_bank_tiles;
};

struct SetProperty : public Pass {
	SetProperty(std::function<const BankTilesMap&()> get_bank_tiles)
		: Pass("set_property", "Set a given property")
		, get_bank_tiles(get_bank_tiles) {
		register_in_tcl_interpreter(pass_name);
	}

	void help() YS_OVERRIDE	{
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
		log("\n");
		log("    set_property PROPERTY VALUE OBJECT\n");
		log("\n");
		log("Set the given property to the specified value on an object\n");
		log("\n");
	}

	void execute(std::vector<std::string> args, RTLIL::Design* design) YS_OVERRIDE {
		if (design->top_module() == nullptr) {
			log_cmd_error("No top module detected\n");
		}

		std::string option(args[1]);
		if (set_property_options_map.count(option) == 0) {
			log_warning("set_property: %s option is currently not supported\n", option.c_str());
			return;
		}

		switch (set_property_options_map.at(option)) {
			case SetPropertyOptions::INTERNAL_VREF:
				process_vref(std::vector<std::string>(args.begin() + 2, args.end()), design);
				break;
			case SetPropertyOptions::IOSTANDARD:
			case SetPropertyOptions::SLEW:
			case SetPropertyOptions::DRIVE:
			case SetPropertyOptions::IN_TERM:
				process_port_parameter(std::vector<std::string>(args.begin() + 1, args.end()), design);
				break;
			default:
				assert(false);
		}
	}

	void process_vref(std::vector<std::string> args, RTLIL::Design* design) {
		if (args.size() < 2) {
			log_error("set_property INTERNAL_VREF: Incorrect number of arguments.\n");
		}
		int iobank = std::atoi(args[1].c_str());
		auto bank_tiles = get_bank_tiles();
		if (bank_tiles.count(iobank) == 0) {
			log_cmd_error("set_property INTERNAL_VREF: Invalid IO bank.\n");
		}

		int internal_vref = 1000 * std::atof(args[0].c_str());
		if (internal_vref != 600 &&
				internal_vref != 675 &&
				internal_vref != 750 &&
				internal_vref != 900) {
			log("set_property INTERNAL_VREF: Incorrect INTERNAL_VREF value\n");
			return;
		}

		// Create a new BANK module if it hasn't been created so far
		RTLIL::Module* top_module = design->top_module();
		if (!design->has(ID(BANK))) {
			std::string fasm_extra_modules_dir(proc_share_dirname() + "/plugins/fasm_extra_modules");
			Pass::call(design, "read_verilog " + fasm_extra_modules_dir + "/BANK.v");
		}

		// Set parameters on a new bank instance or update an existing one
		char bank_cell_name[16];
		snprintf(bank_cell_name, 16, "\\bank_cell_%d", iobank);
		RTLIL::Cell* bank_cell = top_module->cell(RTLIL::IdString(bank_cell_name));
		if (!bank_cell) {
			bank_cell = top_module->addCell(RTLIL::IdString(bank_cell_name), ID(BANK));
		}
		bank_cell->setParam(ID(FASM_EXTRA), RTLIL::Const("INTERNAL_VREF"));
		bank_cell->setParam(ID(NUMBER), RTLIL::Const(iobank));
		bank_cell->setParam(ID(INTERNAL_VREF), RTLIL::Const(internal_vref));
	}

	void process_port_parameter(std::vector<std::string> args, RTLIL::Design* design) {
		if (args.size() < 1) {
			log_error("set_property: Incorrect number of arguments.\n");
		}
		std::string parameter(args.at(0));
		if (args.size() < 3) {
			log_error("set_property %s: Incorrect number of arguments.\n", parameter.c_str());
		}
		std::string port_name(args.at(2));
		std::string value(args.at(1));
		char port[128];
		char bit[64];
		if (sscanf(port_name.c_str(), "%[^[]%s", port, bit) == 2) {
			port_name = std::string(port) + " " + std::string(bit);
		}
		RTLIL::Module* top_module = design->top_module();
		RTLIL::IdString port_id(RTLIL::escape_id(port_name.c_str()));
		for (auto cell_obj : top_module->cells_) {
			RTLIL::Cell* cell = cell_obj.second;
			RTLIL::IdString cell_id = cell_obj.first;
			for (auto connection : cell->connections_) {
				RTLIL::SigSpec cell_signals = connection.second;
				if (!strcmp(log_signal(cell_signals),port_id.c_str())) {
					cell->setParam(RTLIL::IdString(RTLIL::escape_id(parameter)), RTLIL::Const(value));
					log("Setting parameter %s to value %s on cell %s \n", parameter.c_str(), value.c_str(), cell_id.c_str());
				}
			}
		}
	}

	std::function<const BankTilesMap&()> get_bank_tiles;
};

struct ReadXdc : public Frontend {
	ReadXdc()
	       	: Frontend("xdc", "Read XDC file")
		, GetIOBanks(std::bind(&ReadXdc::get_bank_tiles, this))
		, SetProperty(std::bind(&ReadXdc::get_bank_tiles, this)) {}

	void help() YS_OVERRIDE {
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
		log("\n");
		log("    read_xdc -part_json <part_json_filename> <filename>\n");
		log("\n");
		log("Read XDC file.\n");
		log("\n");
	}

	void execute(std::istream *&f, std::string filename, std::vector<std::string> args, RTLIL::Design*) YS_OVERRIDE {
                if (args.size() < 2) {
                        log_cmd_error("Missing script file.\n");
		}
                Tcl_Interp *interp = yosys_get_tcl_interp();
		size_t argidx = 1;
		bank_tiles.clear();
		if (args[argidx] == "-part_json" && argidx + 1 < args.size()) {
			bank_tiles = ::get_bank_tiles(args[++argidx]);
			argidx++;
		}
		extra_args(f, filename, args, argidx);
		std::string content{std::istreambuf_iterator<char>(*f), std::istreambuf_iterator<char>()};
		log("%s\n", content.c_str());
                if (Tcl_EvalFile(interp, args[argidx].c_str()) != TCL_OK) {
                        log_cmd_error("TCL interpreter returned an error: %s\n", Tcl_GetStringResult(interp));
		}
	}
	const BankTilesMap& get_bank_tiles() {
		return bank_tiles;
	}

	BankTilesMap bank_tiles;
	struct GetPorts GetPorts;
	struct GetIOBanks GetIOBanks;
	struct SetProperty SetProperty;
} ReadXdc;

struct GetBankTiles : public Pass {
	GetBankTiles()
	       	: Pass("get_bank_tiles", "Inspect IO Bank tiles") {
		register_in_tcl_interpreter(pass_name);
	}

	void help() YS_OVERRIDE
	{
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
		log("\n");
		log("   get_bank_tiles <part_json_file>\n");
		log("\n");
		log("Inspect IO Bank tiles for the specified part based on the provided JSON file.\n");
		log("\n");
	}

	void execute(std::vector<std::string> args, RTLIL::Design* ) YS_OVERRIDE {
                if (args.size() < 2) {
                        log_cmd_error("Missing JSON file.\n");
		}
		// Check if the part has the specified bank
		auto bank_tiles = get_bank_tiles(args[1]);
		if (bank_tiles.size()) {
			log("Available bank tiles:\n");
			for (auto bank : bank_tiles) {
				log("Bank: %d, Tile: %s\n", bank.first, bank.second.c_str());
			}
			log("\n");
		} else {
			log("No bank tiles available.\n");
		}
	}
} GetBankTiles;

PRIVATE_NAMESPACE_END
