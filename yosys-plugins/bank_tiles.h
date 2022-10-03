/*
 * Copyright 2020-2022 F4PGA Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
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
