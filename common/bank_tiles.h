/*
 * Copyright (C) 2019-2022 The SymbiFlow Authors
 *
 * Use of this source code is governed by a ISC-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/ISC
 *
 * SPDX-License-Identifier: ISC
 *
 */
#include "kernel/log.h"
#include "libs/json11/json11.hpp"

USING_YOSYS_NAMESPACE
// Coordinates of HCLK_IOI tiles associated with a specified bank
using BankTilesMap = std::unordered_map<int, std::string>;

// Find the part's JSON file with information including the IO Banks
// and extract the bank tiles.
inline BankTilesMap get_bank_tiles(const std::string json_file_name)
{
    BankTilesMap bank_tiles;
    std::ifstream json_file(json_file_name);
    if (!json_file.good()) {
        log_cmd_error("Can't open JSON file %s", json_file_name.c_str());
    }
    std::string json_str((std::istreambuf_iterator<char>(json_file)), std::istreambuf_iterator<char>());
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
