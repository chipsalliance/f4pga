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
 *   XDC commands
 *
 *   This plugin operates on the existing design and modifies its structure
 *   based on the content of the XDC (Xilinx Design Constraints) file.
 *   Since the XDC file consists of Tcl commands it is read using Yosys's
 *   Tcl interpreter and processed by the new XDC commands imported to the
 *   Tcl interpreter.
 */
#include "../bank_tiles.h"
#include "../utils.h"
#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/rtlil.h"
#include "libs/json11/json11.hpp"
#include <cassert>

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN

static bool isInputPort(RTLIL::Wire *wire) { return wire->port_input; }
static bool isOutputPort(RTLIL::Wire *wire) { return wire->port_output; }

enum class SetPropertyOptions { INTERNAL_VREF, IOSTANDARD, SLEW, DRIVE, IN_TERM, IO_LOC_PAIRS };

const std::unordered_map<std::string, SetPropertyOptions> set_property_options_map = {{"INTERNAL_VREF", SetPropertyOptions::INTERNAL_VREF},
                                                                                      {"IOSTANDARD", SetPropertyOptions::IOSTANDARD},
                                                                                      {"SLEW", SetPropertyOptions::SLEW},
                                                                                      {"DRIVE", SetPropertyOptions::DRIVE},
                                                                                      {"IN_TERM", SetPropertyOptions::IN_TERM},
                                                                                      {"LOC", SetPropertyOptions::IO_LOC_PAIRS},
                                                                                      {"PACKAGE_PIN", SetPropertyOptions::IO_LOC_PAIRS}};

// Apart from the common I/OBUFs there is also the GTPE2_CHANNEL primitive which has a total
// of four IOPADs (2 IPADs and 2 OPADs) which are directly connected to the GTP[RT]X[PN] ports
// of the BEL. The GTPE2_CHANNEL holds all the placement constraints information of the
// corresponding PADs
const std::unordered_map<std::string, std::vector<std::string>> supported_primitive_parameters = {
  {"OBUF", {"IO_LOC_PAIRS", "IOSTANDARD", "DRIVE", "SLEW", "IN_TERM"}},
  {"OBUFDS", {"IO_LOC_PAIRS", "IOSTANDARD", "SLEW", "IN_TERM"}},
  {"OBUFTDS", {"IO_LOC_PAIRS", "IOSTANDARD", "SLEW", "IN_TERM"}},
  {"IBUF", {"IO_LOC_PAIRS", "IOSTANDARD"}},
  {"IOBUF", {"IO_LOC_PAIRS", "IOSTANDARD", "DRIVE", "SLEW", "IN_TERM"}},
  {"IOBUFDS", {"IO_LOC_PAIRS", "IOSTANDARD", "SLEW", "IN_TERM"}},
  {"IBUFDS_GTE2", {"IO_LOC_PAIRS"}},
  {"GTPE2_CHANNEL", {"IO_LOC_PAIRS"}}};

void register_in_tcl_interpreter(const std::string &command)
{
    Tcl_Interp *interp = yosys_get_tcl_interp();
    std::string tcl_script = stringf("proc %s args { return [yosys %s {*}$args] }", command.c_str(), command.c_str());
    Tcl_Eval(interp, tcl_script.c_str());
}

struct GetIOBanks : public Pass {
    GetIOBanks(std::function<const BankTilesMap &()> get_bank_tiles) : Pass("get_iobanks", "Set IO Bank number"), get_bank_tiles(get_bank_tiles)
    {
        register_in_tcl_interpreter(pass_name);
    }

    void help() override
    {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("   get_iobanks <bank_number>\n");
        log("\n");
        log("Get IO Bank number\n");
        log("\n");
    }

    void execute(std::vector<std::string> args, RTLIL::Design *) override
    {
        if (args.size() < 2) {
            log_cmd_error("%s: Missing bank number.\n", pass_name.c_str());
        }
        auto bank_tiles = get_bank_tiles();
        if (bank_tiles.count(std::atoi(args[1].c_str())) == 0) {
            log_cmd_error("%s:Bank number %s is not present in the target device.\n", args[1].c_str(), pass_name.c_str());
        }

        Tcl_Interp *interp = yosys_get_tcl_interp();
        Tcl_SetResult(interp, const_cast<char *>(args[1].c_str()), NULL);
        log("%s\n", args[1].c_str());
    }

    std::function<const BankTilesMap &()> get_bank_tiles;
};

struct SetProperty : public Pass {
    SetProperty(std::function<const BankTilesMap &()> get_bank_tiles) : Pass("set_property", "Set a given property"), get_bank_tiles(get_bank_tiles)
    {
        register_in_tcl_interpreter(pass_name);
    }

    void help() override
    {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("    set_property PROPERTY VALUE OBJECT\n");
        log("or\n");
        log("    set_property -dict { PROPERTY VALUE PROPERTY2 VALUE2 } OBJECT\n");
        log("\n");
        log("Set the given property to the specified value on an object\n");
        log("\n");
    }

    void execute(std::vector<std::string> args, RTLIL::Design *design) override
    {
        if (design->top_module() == nullptr) {
            log_cmd_error("No top module detected\n");
        }
        if (args.at(1) == "-dict") {
            std::string dict_args = args.at(2);
            trim(dict_args);
            std::stringstream args_stream(dict_args);
            std::vector<std::string> tokens;
            std::string intermediate;
            while (getline(args_stream, intermediate, ' ')) {
                if (intermediate != "\0") {
                    tokens.push_back(intermediate);
                }
            }
            if (tokens.size() % 2 != 0) {
                log_cmd_error("Invalid number of dict parameters: %lu.\n", tokens.size());
            }
            for (long unsigned int i = 0; i < tokens.size(); i += 2) {
                std::vector<std::string> new_args(args);
                new_args.at(1) = tokens[i];
                new_args.at(2) = tokens[i + 1];
                read_property(new_args, design);
            }
        } else {
            read_property(args, design);
        }
    }

    void read_property(std::vector<std::string> args, RTLIL::Design *design)
    {
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
        case SetPropertyOptions::IO_LOC_PAIRS: {
            // args "set_property LOC PAD PORT" become "IO_LOC_PAIRS PORT:PAD PORT"
            std::vector<std::string> new_args(args.begin() + 1, args.end());
            new_args.at(0) = "IO_LOC_PAIRS";
            new_args.at(1) = new_args.at(2) + ":" + new_args.at(1);
            process_port_parameter(new_args, design);
            break;
        }
        default:
            assert(false);
        }
    }

    void process_vref(std::vector<std::string> args, RTLIL::Design *design)
    {
        if (args.size() < 2) {
            log_error("set_property INTERNAL_VREF: Incorrect number of arguments.\n");
        }
        int iobank = std::atoi(args[1].c_str());
        auto bank_tiles = get_bank_tiles();
        if (bank_tiles.count(iobank) == 0) {
            log_cmd_error("set_property INTERNAL_VREF: Invalid IO bank.\n");
        }

        int internal_vref = 1000 * std::atof(args[0].c_str());
        if (internal_vref != 600 && internal_vref != 675 && internal_vref != 750 && internal_vref != 900) {
            log("set_property INTERNAL_VREF: Incorrect INTERNAL_VREF value\n");
            return;
        }

        // Create a new BANK module if it hasn't been created so far
        RTLIL::Module *top_module = design->top_module();
        if (!design->has(ID(BANK))) {
            std::string fasm_extra_modules_dir(proc_share_dirname() + "/plugins/fasm_extra_modules");
            Pass::call(design, "read_verilog " + fasm_extra_modules_dir + "/BANK.v");
        }

        // Set parameters on a new bank instance or update an existing one
        char bank_cell_name[16];
        snprintf(bank_cell_name, 16, "\\bank_cell_%d", iobank);
        RTLIL::Cell *bank_cell = top_module->cell(RTLIL::IdString(bank_cell_name));
        if (!bank_cell) {
            bank_cell = top_module->addCell(RTLIL::IdString(bank_cell_name), ID(BANK));
        }
        bank_cell->setParam(ID(FASM_EXTRA), RTLIL::Const("INTERNAL_VREF"));
        bank_cell->setParam(ID(NUMBER), RTLIL::Const(iobank));
        bank_cell->setParam(ID(INTERNAL_VREF), RTLIL::Const(internal_vref));
    }

    void process_port_parameter(std::vector<std::string> args, RTLIL::Design *design)
    {
        if (args.size() < 1) {
            log_error("set_property: Incorrect number of arguments.\n");
        }

        std::string parameter(args.at(0));
        if (args.size() < 3 || args.at(2).size() == 0) {
            log_error("set_property %s: Incorrect number of arguments.\n", parameter.c_str());
        }

        std::string port_name(args.at(2));
        std::string value(args.at(1));

        auto port_signal = extract_signal(port_name);
        std::string port(port_signal.first);
        int port_bit = port_signal.second;

        RTLIL::Wire *wire = design->top_module()->wire(RTLIL::escape_id(port));
        if (wire == nullptr) {
            log_error("Couldn't find port %s\n", port_name.c_str());
        }

        if (!isInputPort(wire) && !isOutputPort(wire)) {
            log_error("Port %s is not a top port\n", port_name.c_str());
        }

        if (port_bit < wire->start_offset || port_bit >= wire->start_offset + wire->width) {
            log_error("Incorrect top port index %d in port %s\n", port_bit, port_name.c_str());
        }

        // Traverse the port wire
        traverse_wire(port_name, design->top_module());

        RTLIL::IdString parameter_id(RTLIL::escape_id(parameter));
        for (auto cell_obj : design->top_module()->cells_) {
            RTLIL::IdString cell_id = cell_obj.first;
            RTLIL::Cell *cell = cell_obj.second;

            // Check if the cell is of the type we are looking for
            auto cell_type_str = RTLIL::unescape_id(cell->type.str());
            auto primitive_parameters_iter = supported_primitive_parameters.find(cell_type_str);
            if (primitive_parameters_iter == supported_primitive_parameters.end()) {
                continue;
            }

            // Set the parameter on the cell connected to the selected port
            for (auto connection : cell->connections_) {
                RTLIL::SigSpec cell_signal = connection.second;
                if (is_signal_port(cell_signal, port_name)) {
                    // Check if the attribute is allowed for this module
                    auto primitive_parameters = primitive_parameters_iter->second;
                    if (std::find(primitive_parameters.begin(), primitive_parameters.end(), parameter) == primitive_parameters.end()) {
                        log_error("Cell %s of type %s doesn't support the %s attribute\n", cell->name.c_str(), cell->type.c_str(),
                                  parameter_id.c_str());
                    }
                    if (parameter_id == ID(IO_LOC_PAIRS) and cell->hasParam(parameter_id)) {
                        std::string cur_value(cell->getParam(parameter_id).decode_string());
                        value = cur_value + "," + value;
                    }
                    cell->setParam(parameter_id, RTLIL::Const(value));
                    log("Setting parameter %s to value %s on cell %s \n", parameter_id.c_str(), value.c_str(), cell_obj.first.c_str());
                }
            }
        }
        log("\n");
    }

    // Search module's connections for the specified destination port
    // and traverse from the specified destination wire to the source wire
    void traverse_wire(std::string &port_name, RTLIL::Module *module)
    {
        auto port_signal = extract_signal(port_name);
        std::string signal_name(port_signal.first);
        auto signal_name_idstr = RTLIL::IdString(RTLIL::escape_id(signal_name));
        int port_bit = port_signal.second;
        for (auto connection : module->connections_) {
            auto dst_sig = connection.first;
            auto src_sig = connection.second;
            if (dst_sig.is_chunk()) {
                auto chunk = dst_sig.as_chunk();
                if (chunk.wire) {
                    if (chunk.wire->name != signal_name_idstr) {
                        continue;
                    }
                    if (port_bit < chunk.offset || port_bit >= (chunk.offset + chunk.width)) {
                        continue;
                    }
                    auto src_wires = src_sig.to_sigbit_vector();
                    auto src_wire_sigbit = src_wires.at(port_bit - chunk.offset);
                    if (src_wire_sigbit.wire) {
                        port_name = src_wires.at(port_bit - chunk.offset).wire->name.str();
                        if (src_wire_sigbit.offset > 0) {
                            port_name += "[" + std::to_string(src_wire_sigbit.offset) + "]";
                        }
                        return;
                    }
                }
            }
        }
    }

    // Extract signal name and port bit information from port name
    std::pair<std::string, int> extract_signal(const std::string &port_name)
    {
        int port_bit(0);
        std::string port_str(port_name.size(), '\0');
        sscanf(port_name.c_str(), "%[^[][%d]", &port_str[0], &port_bit);
        port_str.resize(strlen(port_str.c_str()));
        return std::make_pair(port_str, port_bit);
    }

    // Check if the specified port name is part of the provided connection signal
    bool is_signal_port(RTLIL::SigSpec signal, const std::string &port_name)
    {
        auto port_signal = extract_signal(port_name);
        std::string port(port_signal.first);
        int port_bit = port_signal.second;
        if (signal.is_chunk()) {
            auto chunk = signal.as_chunk();
            if (chunk.wire) {
                // chunk.offset is always indexed from 0. Because of that port_bit must be
                // corrected with the chunk.wire->start_offset of the port wire in case it is not 0-indexed.
                // Not doing this would cause lack of some properties (e.g. IO_LOC_PAIRS) for
                // non-0-indexed ports in final eblif file
                return (chunk.wire->name == RTLIL::IdString(RTLIL::escape_id(port))) && ((port_bit - chunk.wire->start_offset) == chunk.offset);
            }
        }
        return false;
    }

    std::function<const BankTilesMap &()> get_bank_tiles;
};

struct ReadXdc : public Frontend {
    ReadXdc()
        : Frontend("xdc", "Read XDC file"), GetIOBanks(std::bind(&ReadXdc::get_bank_tiles, this)),
          SetProperty(std::bind(&ReadXdc::get_bank_tiles, this))
    {
    }

    void help() override
    {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("    read_xdc -part_json <part_json_filename> <filename>\n");
        log("\n");
        log("Read XDC file.\n");
        log("\n");
    }

    void execute(std::istream *&f, std::string filename, std::vector<std::string> args, RTLIL::Design *) override
    {
        if (args.size() < 2) {
            log_cmd_error("Missing script file.\n");
        }
        size_t argidx = 1;
        bank_tiles.clear();
        if (args[argidx] == "-part_json" && argidx + 1 < args.size()) {
            bank_tiles = ::get_bank_tiles(args[++argidx]);
            argidx++;
        }
        extra_args(f, filename, args, argidx);
        std::string content{std::istreambuf_iterator<char>(*f), std::istreambuf_iterator<char>()};
        log("%s\n", content.c_str());

        // According to page 6 of UG903 XDC is tcl, hence quoting of bracketed numbers,
        // such as bus indexes, is required. For example "signal[5]" would be typically
        // expanded to the concatenation of the string "signal" and result of the function call "5"
        // with no arguments. Therefore in TCL the signal indices have to be wrapped in curly braces
        // e.g "{signal[5]}" in order for the interpreter to not perform any variable substitution
        // or function calls on the wrapped content.
        //
        // Nevertheless, it's quite common for EDA tools to allow for specifying signal indices
        // (e.g. "signal[5]") without using non-expanding quotes.
        // Possible TCL implementations of such a feature include registering a TCL command
        // for each integer which returns itself but surrounded with brackets or using the 'unknown'
        // command which is invoked by the Tcl interpreter whenever a script tries to invoke a command
        // that does not exist. In the XDC plugin the latter approach is used, however it's limited to
        // the 'read_xdc' command, hence the 'unknown' command works solely on the content of the XDC file.
        //
        // In this implementation the signal "signal[5]" is expanded in TCL to the concatenation of a string
        // and function call, however this time the handling of the non-existent command '5' is passed by
        // the interpreter to the 'unknown' command which returns a string that consists of the indice
        // integer surrounded by square brackets, i.e. "[5]", effectively expanding the signal to "signal[5]"
        // string.
        //
        Tcl_Interp *interp = yosys_get_tcl_interp();
        Tcl_Eval(interp, "rename unknown _original_unknown");
        Tcl_Eval(interp, "proc unknown args { return \\[[lindex $args 0]\\] }");
        if (Tcl_EvalFile(interp, args[argidx].c_str()) != TCL_OK) {
            log_cmd_error("TCL interpreter returned an error: %s\n", Tcl_GetStringResult(interp));
        }
        Tcl_Eval(interp, "rename unknown \"\"");
        Tcl_Eval(interp, "rename _original_unknown unknown");
    }
    const BankTilesMap &get_bank_tiles() { return bank_tiles; }

    BankTilesMap bank_tiles;
    struct GetIOBanks GetIOBanks;
    struct SetProperty SetProperty;
} ReadXdc;

struct GetBankTiles : public Pass {
    GetBankTiles() : Pass("get_bank_tiles", "Inspect IO Bank tiles") { register_in_tcl_interpreter(pass_name); }

    void help() override
    {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("   get_bank_tiles <part_json_file>\n");
        log("\n");
        log("Inspect IO Bank tiles for the specified part based on the provided JSON file.\n");
        log("\n");
    }

    void execute(std::vector<std::string> args, RTLIL::Design *) override
    {
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
