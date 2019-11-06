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
 *   XDC commands + FASM backend.
 *
 *   This plugin operates on the existing design and modifies its structure
 *   based on the content of the XDC (Xilinx Design Constraints) file.
 *   Since the XDC file consists of Tcl commands it is read using Yosys's
 *   tcl command and processed by the new XDC commands imported to the
 *   Tcl interpreter.
 */

#include "kernel/register.h"
#include "kernel/rtlil.h"
#include "kernel/log.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

int current_iobank = 0;

// IO Banks that are present on the device.
// This is very part specific and is for Arty's xc7a35tcsg324 part.
std::vector<int> io_banks = {14, 15, 16, 34, 35};

enum SetPropertyOptions { INTERNAL_VREF };

std::unordered_map<std::string, SetPropertyOptions> set_property_options_map  = {
	{"INTERNAL_VREF", INTERNAL_VREF}
};

struct GetPorts : public Pass {
	GetPorts() : Pass("get_ports", "Print matching ports") {}
	void help() YS_OVERRIDE
	{
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
		log("\n");
		log("   get_ports \n");
		log("\n");
		log("Get matching ports\n");
		log("\n");
		log("Print the output to stdout too. This is useful when all Yosys is executed\n");
		log("\n");
	}
	void execute(std::vector<std::string> args, RTLIL::Design*) YS_OVERRIDE
	{
		std::string text;
		for (auto& arg : args) {
			text += arg + ' ';
		}
		if (!text.empty()) text.resize(text.size()-1);
		log("%s\n", text.c_str());
	}
} GetPorts;

struct GetIOBanks : public Pass {
	GetIOBanks() : Pass("get_iobanks", "Set IO Bank number") {}
	void help() YS_OVERRIDE
	{
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
		log("\n");
		log("   get_iobanks \n");
		log("\n");
		log("Get IO Bank number\n");
		log("\n");
	}
	void execute(std::vector<std::string> args, RTLIL::Design* ) YS_OVERRIDE
	{
		if (args.size() != 2) {
			log("Incorrect number of arguments. %zu instead of 1", args.size());
			return;
		}
		current_iobank = std::atoi(args[1].c_str());
		if (std::find(io_banks.begin(), io_banks.end(), current_iobank) == io_banks.end()) {
			log("get_iobanks: Incorrect bank number: %d\n", current_iobank);
			current_iobank = 0;
		}
	}
} GetIOBanks;

struct SetProperty : public Pass {
	SetProperty() : Pass("set_property", "Set a given property") {}
	void help() YS_OVERRIDE
	{
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
		log("\n");
		log("    set_property PROPERTY VALUE OBJECT\n");
		log("\n");
		log("Set the given property to the specified value on an object\n");
		log("\n");
	}
	void execute(std::vector<std::string> args, RTLIL::Design* design) YS_OVERRIDE
	{
		if (design->top_module() == nullptr) {
			log("No top module detected\n");
			return;
		}

		std::string option(args[1]);
		if (set_property_options_map.count(option) == 0) {
			log("set_property: %s option is currently not supported\n", option.c_str());
			return;
		}

		switch (set_property_options_map[option]) {
			case INTERNAL_VREF:
				process_vref(std::vector<std::string>(args.begin() + 2, args.end()), design);
				break;
			default:
				assert(false);
		}
	}
	void process_vref(std::vector<std::string> args, RTLIL::Design* design)
       	{
		if (args.size() != 2) {
			log("set_property INTERNAL_VREF: Incorrect number of arguments: %zu\n", args.size());
			return;
		}

		if (current_iobank == 0) {
			log("set_property INTERNAL_VREF: No valid bank set. Use get_iobanks.\n");
			return;
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
			RTLIL::Module* bank_module = design->addModule(ID(BANK));
			bank_module->makeblackbox();
			bank_module->avail_parameters.insert(ID(NUMBER));
			bank_module->avail_parameters.insert(ID(INTERNAL_VREF));
		}

		// Set parameters on a new bank instance or update an existing one
		char bank_cell_name[16];
		snprintf(bank_cell_name, 16, "\\bank_cell_%d", current_iobank);
		RTLIL::Cell* bank_cell = top_module->cell(RTLIL::IdString(bank_cell_name));
		if (!bank_cell) {
			bank_cell = top_module->addCell(RTLIL::IdString(bank_cell_name), ID(BANK));
		}
		bank_cell->setParam(ID(NUMBER), RTLIL::Const(current_iobank));
		bank_cell->setParam(ID(INTERNAL_VREF), RTLIL::Const(internal_vref));
	}

} SetProperty;

PRIVATE_NAMESPACE_END
