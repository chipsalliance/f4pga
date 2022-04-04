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
 *  ---
 *
 *   FASM backend
 *
 *   This plugin writes out the design's fasm features based on the parameter
 *   annotations on the design cells.
 */

#include "../common/bank_tiles.h"
#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/rtlil.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

struct WriteFasm : public Backend {
    WriteFasm() : Backend("fasm", "Write out FASM features") {}

    void help() override
    {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("    write_fasm -part_json <part_json_filename> <filename>\n");
        log("\n");
        log("Write out a file with vref FASM features.\n");
        log("\n");
    }

    void execute(std::ostream *&f, std::string filename, std::vector<std::string> args, RTLIL::Design *design) override
    {
        size_t argidx = 1;
        std::string part_json;
        if (args[argidx] == "-part_json" && argidx + 1 < args.size()) {
            part_json = args[++argidx];
            argidx++;
        }
        extra_args(f, filename, args, argidx);
        extract_fasm_features(f, design, part_json);
    }

    void extract_fasm_features(std::ostream *&f, RTLIL::Design *design, const std::string &part_json)
    {
        RTLIL::Module *top_module(design->top_module());
        if (top_module == nullptr) {
            log_cmd_error("%s: No top module detected.\n", pass_name.c_str());
        }
        auto bank_tiles = get_bank_tiles(part_json);
        // Generate a fasm feature associated with the INTERNAL_VREF value per bank
        // e.g. VREF value of 0.675 for bank 34 is associated with tile HCLK_IOI3_X113Y26
        // hence we need to emit the following fasm feature: HCLK_IOI3_X113Y26.VREF.V_675_MV
        for (auto cell : top_module->cells()) {
            if (!cell->hasParam(ID(FASM_EXTRA)))
                continue;
            if (cell->getParam(ID(FASM_EXTRA)) == RTLIL::Const("INTERNAL_VREF")) {
                if (bank_tiles.size() == 0) {
                    log_cmd_error("%s: No bank tiles available on the target part.\n", pass_name.c_str());
                }
                int bank_number(cell->getParam(ID(NUMBER)).as_int());
                if (bank_tiles.count(bank_number) == 0) {
                    log_cmd_error("%s: No IO bank number %d on the target part.\n", pass_name.c_str(), bank_number);
                }
                int bank_vref(cell->getParam(ID(INTERNAL_VREF)).as_int());
                *f << "HCLK_IOI3_" << bank_tiles[bank_number] << ".VREF.V_" << bank_vref << "_MV\n";
            }
        }
    }
} WriteFasm;

PRIVATE_NAMESPACE_END
