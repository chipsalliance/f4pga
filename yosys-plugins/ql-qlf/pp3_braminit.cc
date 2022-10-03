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

#include "kernel/sigtools.h"
#include "kernel/yosys.h"
#include <bitset>
#include <stdio.h>
#include <stdlib.h>

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

static void run_pp3_braminit(Module *module)
{
    for (auto cell : module->selected_cells()) {
        uint32_t mem[2048];
        int32_t ramDataWidth = 32;
        int32_t ramDataDepth = 512;

        log("cell type %s\n", RTLIL::id2cstr(cell->name));

        /* Only consider cells we're interested in */
        if (cell->type != ID(RAM_16K_BLK) && cell->type != ID(RAM_8K_BLK))
            continue;
        log("found ram block\n");
        if (!cell->hasParam(ID(INIT_FILE)))
            continue;
        std::string init_file = cell->getParam(ID(INIT_FILE)).decode_string();
        cell->unsetParam(ID(INIT_FILE));
        if (init_file == "")
            continue;

        /* Open file */
        log("Processing %s : %s\n", RTLIL::id2cstr(cell->name), init_file.c_str());
        ramDataWidth = cell->getParam(ID(data_width_int)).as_int();
        ramDataDepth = cell->getParam(ID(data_depth_int)).as_int();

        std::ifstream f;
        f.open(init_file.c_str());
        if (f.fail()) {
            log("Can not open file `%s`.\n", init_file.c_str());
            continue;
        }

        /* Defaults to 0 */
        memset(mem, 0x00, sizeof(mem));

        /* Process each line */
        bool in_comment = false;
        int cursor = 0;

        while (!f.eof()) {
            std::string line, token;
            std::getline(f, line);

            for (int i = 0; i < GetSize(line); i++) {
                if (in_comment && line.compare(i, 2, "*/") == 0) {
                    line[i] = ' ';
                    line[i + 1] = ' ';
                    in_comment = false;
                    continue;
                }
                if (!in_comment && line.compare(i, 2, "/*") == 0)
                    in_comment = true;
                if (in_comment)
                    line[i] = ' ';
            }

            while (1) {
                bool set_cursor = false;
                long value;

                token = next_token(line, " \t\r\n");
                if (token.empty() || token.compare(0, 2, "//") == 0)
                    break;

                if (token[0] == '@') {
                    token = token.substr(1);
                    set_cursor = true;
                }

                const char *nptr = token.c_str();
                char *endptr;
                value = strtol(nptr, &endptr, 16);
                if (!*nptr || *endptr) {
                    log("Can not parse %s `%s` for %s.\n", set_cursor ? "address" : "value", nptr, token.c_str());
                    continue;
                }

                if (set_cursor)
                    cursor = value;
                else if (cursor >= 0 && cursor < ramDataDepth)
                    mem[cursor++] = value;
                else
                    log("Attempt to initialize non existent address %d\n", cursor);
            }
        }

        // TODO: Support RAM initialization for other widths than 8, 16 and 32
        if (ramDataWidth != 8 && ramDataWidth != 16 && ramDataWidth != 32) {
            log("WARNING: The RAM cell '%s' has data width of %d. Initialization of this width from a file is not supported yet!\n",
                RTLIL::id2cstr(cell->name), ramDataWidth);
            continue;
        }

        /* Set attributes */
        std::string val = "";
        for (int i = ramDataDepth - 1; i >= 0; i--) {
            if (ramDataWidth == 8)
                val += std::bitset<8>(mem[i]).to_string();
            else if (ramDataWidth == 16)
                val += std::bitset<16>(mem[i]).to_string();
            else if (ramDataWidth == 32)
                val += std::bitset<32>(mem[i]).to_string();
        }
        cell->setParam(RTLIL::escape_id("INIT"), RTLIL::Const::from_string(val));
    }
}

struct PP3BRAMInitPass : public Pass {
    PP3BRAMInitPass() : Pass("pp3_braminit", "PP3: perform RAM Block initialization from file") {}
    void help() override
    {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("    pp3_braminit\n");
        log("\n");
        log("This command processes all PP3 RAM blocks with a non-empty INIT_FILE\n");
        log("parameter and converts it into the required INIT attributes\n");
        log("\n");
    }
    void execute(std::vector<std::string> args, RTLIL::Design *design) override
    {
        log_header(design, "Executing PP3_BRAMINIT pass.\n");

        extra_args(args, 1, design);

        for (auto module : design->selected_modules())
            run_pp3_braminit(module);
    }
} PP3BRAMInitPass;

PRIVATE_NAMESPACE_END
