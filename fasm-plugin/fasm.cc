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
 *   FASM backend
 *
 *   This plugin writes out the design's fasm features based on the parameter
 *   annotations on the design cells.
 */

#include "kernel/register.h"
#include "kernel/rtlil.h"
#include "kernel/log.h"
#include "../bank_tiles.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

struct WriteFasm : public Backend {
	WriteFasm() : Backend("fasm", "Write out FASM features") {}


	void help() YS_OVERRIDE {
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
		log("\n");
		log("    write_fasm -part_json <part_json_filename> <filename>\n");
		log("\n");
		log("Write out a file with vref FASM features.\n");
		log("\n");
	}

	void execute(std::ostream *&f, std::string filename,  std::vector<std::string> args, RTLIL::Design *design) YS_OVERRIDE {
		size_t argidx = 1;
		std::string part_json;
		if (args[argidx] == "-part_json" && argidx + 1 < args.size()) {
			part_json = args[++argidx];
			argidx++;
		}
		extra_args(f, filename, args, argidx);
		extract_fasm_features(f, design, part_json);
	}

	void extract_fasm_features(std::ostream *&f, RTLIL::Design* design, const std::string& part_json) {
		RTLIL::Module* top_module(design->top_module());
		if (top_module == nullptr) {
			log_cmd_error("%s: No top module detected.\n", pass_name.c_str());
		}
		auto bank_tiles = get_bank_tiles(part_json);
		// Generate a fasm feature associated with the INTERNAL_VREF value per bank
		// e.g. VREF value of 0.675 for bank 34 is associated with tile HCLK_IOI3_X113Y26
		// hence we need to emit the following fasm feature: HCLK_IOI3_X113Y26.VREF.V_675_MV
		for (auto cell : top_module->cells()) {
			if (!cell->hasParam(ID(FASM_EXTRA))) continue;
			if (cell->getParam(ID(FASM_EXTRA)) == RTLIL::Const("INTERNAL_VREF")) {
				if (bank_tiles.size() == 0) {
					log_cmd_error("%s: No bank tiles available on the target part.\n", pass_name.c_str());
				}
				int bank_number(cell->getParam(ID(NUMBER)).as_int());
				if (bank_tiles.count(bank_number) == 0) {
					log_cmd_error("%s: No IO bank number %d on the target part.\n", pass_name.c_str(), bank_number);
				}
				int bank_vref(cell->getParam(ID(INTERNAL_VREF)).as_int());
				*f << "HCLK_IOI3_" << bank_tiles[bank_number] <<".VREF.V_" << bank_vref << "_MV\n";
			}
		}
	}
} WriteFasm;

PRIVATE_NAMESPACE_END
