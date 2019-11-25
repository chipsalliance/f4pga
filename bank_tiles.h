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
 */
#include "kernel/log.h"
#include "libs/json11/json11.hpp"


USING_YOSYS_NAMESPACE
// Coordinates of HCLK_IOI tiles associated with a specified bank
using BankTilesMap = std::unordered_map<int, std::string>;

// Find the part's JSON file with information including the IO Banks
// and extract the bank tiles.
BankTilesMap get_bank_tiles(const std::string json_file_name) {
	BankTilesMap bank_tiles;
	std::ifstream json_file(json_file_name);
	if (!json_file.good()) {
		log_cmd_error("Can't open JSON file %s", json_file_name.c_str());
	}
	std::string json_str((std::istreambuf_iterator<char>(json_file)),
			std::istreambuf_iterator<char>());
	std::string error;
	auto json = json11::Json::parse(json_str, error);
	if (!error.empty()) {
		log_cmd_error("%s\n", error.c_str());
	}
	auto json_objects = json.object_items();
	auto iobanks = json_objects.find("iobanks");
	if (iobanks == json_objects.end()) {
		log_cmd_error("IO Bank information missing in the part's json: %s\n", json_file_name.c_str());
	}

	for (auto iobank : iobanks->second.object_items()) {
		bank_tiles.emplace(std::atoi(iobank.first.c_str()), iobank.second.string_value());
	}

	return bank_tiles;
}

