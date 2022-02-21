// Copyright (C) 2020-2022  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/rtlil.h"
#include "kernel/sigtools.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

// ============================================================================

struct QlDspSimdPass : public Pass {

    QlDspSimdPass () : Pass("ql_dsp_simd", "Infers QuickLogic k6n10f DSP pairs that can operate in SIMD mode") {}

    void help() override {
        log("\n");
        log("    ql_dsp_simd [selection]\n");
        log("\n");
        log("    This pass identifies k6n10f DSP cells with identical configuration\n");
        log("    and packs pairs of them together into other DSP cells that can\n");
        log("    perform SIMD operation.\n");
    }

    // ..........................................

    /// Describes DSP config unique to a whole DSP cell
    struct DspConfig {

        // Port connections
        dict<RTLIL::IdString, RTLIL::SigSpec> connections;

        // TODO: Possibly include parameters here. For now we have just
        // connections.

        DspConfig () = default;

        DspConfig (const DspConfig& ref) = default;
        DspConfig (DspConfig&& ref) = default;

        unsigned int hash () const {
            return connections.hash();
        }

        bool operator == (const DspConfig& ref) const {
            return connections == ref.connections;
        }
    };

    // ..........................................

    // DSP control and config ports to consider and how to map them to ports
    // of the target DSP cell
    const std::vector<std::pair<std::string, std::string>> m_DspCfgPorts = {
        std::make_pair("clock_i",           "clk"),
        std::make_pair("reset_i",           "reset"),

        std::make_pair("feedback_i",        "feedback"),
        std::make_pair("load_acc_i",        "load_acc"),
        std::make_pair("unsigned_a_i",      "unsigned_a"),
        std::make_pair("unsigned_b_i",      "unsigned_b"),

        std::make_pair("output_select_i",   "output_select"),
        std::make_pair("saturate_enable_i", "saturate_enable"),
        std::make_pair("shift_right_i",     "shift_right"),
        std::make_pair("round_i",           "round"),
        std::make_pair("subtract_i",        "subtract"),
        std::make_pair("register_inputs_i", "register_inputs")
    };

    // DSP data ports and how to map them to ports of the target DSP cell
    const std::vector<std::pair<std::string, std::string>> m_DspDataPorts = {
        std::make_pair("a_i",       "a"),
        std::make_pair("b_i",       "b"),
        std::make_pair("acc_fir_i", "acc_fir"),
        std::make_pair("z_o",       "z"),
        std::make_pair("dly_b_o",   "dly_b"),
    };

    // Source DSP cell type (SISD)
    const RTLIL::IdString m_SisdDspType = RTLIL::escape_id("dsp_t1_10x9x32");
    // Target DSP cell type for the SIMD mode
    const RTLIL::IdString m_SimdDspType = RTLIL::escape_id("QL_DSP2");

    /// Temporary SigBit to SigBit helper map.
    SigMap m_SigMap;

    // ..........................................

    void execute (std::vector<std::string> a_Args, RTLIL::Design* a_Design) override {
        log_header(a_Design, "Executing QL_DSP_SIMD pass.\n");

        // Parse args
        extra_args(a_Args, 1, a_Design);   

        // Process modules
        for (auto module : a_Design->selected_modules()) {

            // Setup the SigMap
            m_SigMap.clear();
            m_SigMap.set(module);

            // Assemble DSP cell groups
            dict<DspConfig, std::vector<RTLIL::Cell*>> groups;
            for (auto cell : module->selected_cells()) {

                // Check if this is a DSP cell
                if (cell->type != m_SisdDspType) {
                    continue;
                }

                // Skip if it has the (* keep *) attribute set
                if (cell->has_keep_attr()) {
                    continue;
                }

                // Add to a group
                const auto key = getDspConfig(cell);
                groups[key].push_back(cell);

            }

            std::vector<const RTLIL::Cell*> cellsToRemove;

            // Map cell pairs to the target DSP SIMD cell
            for (const auto& it : groups) {
                const auto& group  = it.second;
                const auto& config = it.first;

                // Ensure an even number
                size_t count = group.size();
                if (count & 1) count--;

                // Map SIMD pairs
                for (size_t i=0; i < count; i+=2) {
                    const RTLIL::Cell* dsp_a = group[i];
                    const RTLIL::Cell* dsp_b = group[i+1];

                    std::string name = stringf("simd_%s_%s",
                        RTLIL::unescape_id(dsp_a->name).c_str(),
                        RTLIL::unescape_id(dsp_b->name).c_str()
                    );

                    log(" SIMD: %s (%s) + %s (%s) => %s (%s)\n",
                        RTLIL::unescape_id(dsp_a->name).c_str(),
                        RTLIL::unescape_id(dsp_a->type).c_str(),
                        RTLIL::unescape_id(dsp_b->name).c_str(),
                        RTLIL::unescape_id(dsp_b->type).c_str(),
                        RTLIL::unescape_id(name).c_str(),
                        RTLIL::unescape_id(m_SimdDspType).c_str()
                    );

                    // Create the new cell
                    RTLIL::Cell* simd = module->addCell(
                        RTLIL::escape_id(name),
                        m_SimdDspType
                    );

                    // Check if the target cell is known (important to know
                    // its port widths)
                    if (!simd->known()) {
                        log_error(" The target cell type '%s' is not known!",
                            RTLIL::unescape_id(m_SimdDspType).c_str()
                        );
                    }

                    // Connect common ports
                    for (const auto& it : m_DspCfgPorts) {
                        auto sport = RTLIL::escape_id(it.first);
                        auto dport = RTLIL::escape_id(it.second);

                        simd->setPort(dport, config.connections.at(sport));
                    }

                    // Connect data ports
                    for (const auto& it : m_DspDataPorts) {
                        auto sport = RTLIL::escape_id(it.first);
                        auto dport = RTLIL::escape_id(it.second);

                        RTLIL::SigSpec sigspec;
                        size_t width = getPortWidth(simd, dport);

                        // A part
                        if (dsp_a->hasPort(sport)) {
                            const auto& sig = dsp_a->getPort(sport);
                            sigspec.append(sig);
                            if (sig.bits().size() < width / 2) {
                                sigspec.append(RTLIL::SigSpec(RTLIL::Sx,
                                    sig.bits().size() - width / 2)
                                );
                            }
                        } else {                            
                            sigspec.append(RTLIL::SigSpec(RTLIL::Sx, width / 2));
                        }

                        // B part
                        if (dsp_b->hasPort(sport)) {
                            const auto& sig = dsp_b->getPort(sport);
                            sigspec.append(sig);
                            if (sig.bits().size() < width / 2) {
                                sigspec.append(RTLIL::SigSpec(RTLIL::Sx,
                                    sig.bits().size() - width / 2)
                                );
                            }
                        } else {                            
                            sigspec.append(RTLIL::SigSpec(RTLIL::Sx, width / 2));
                        }

                        simd->setPort(dport, sigspec);
                    }

                    // Enable the fractured mode by connecting the control
                    // port.
                    simd->setPort(RTLIL::escape_id("f_mode"), RTLIL::S1);

                    // Mark DSP parts for removal
                    cellsToRemove.push_back(dsp_a);
                    cellsToRemove.push_back(dsp_b);
                }
            }

            // Remove old cells
            for (const auto& cell : cellsToRemove) {
                module->remove(const_cast<RTLIL::Cell*>(cell));
            }
        }

        // Clear
        m_SigMap.clear();
    }

    // ..........................................

    /// Looks up port width in the cell definition and returns it. Returns 0
    /// if it cannot be determined.
    size_t getPortWidth (RTLIL::Cell* a_Cell, RTLIL::IdString a_Port) {

        if (!a_Cell->known()) {
            return 0;
        }

        // Get the module defining the cell (the previous condition ensures
        // that the pointers are valid)
        RTLIL::Module* mod = a_Cell->module->design->module(a_Cell->type);
        if (mod == nullptr) {
            return 0;
        }

        // Get the wire representing the port
        RTLIL::Wire* wire = mod->wire(a_Port);
        if (wire == nullptr) {
            return 0;
        }

        return wire->width;
    }

    /// Given a DSP cell populates and returns a DspConfig struct for it.
    DspConfig getDspConfig (RTLIL::Cell* a_Cell) {
        DspConfig config;

        for (const auto& it : m_DspCfgPorts) {
            auto port = RTLIL::escape_id(it.first);

            // Port unconnected
            if (!a_Cell->hasPort(port)) {
                config.connections[port] = RTLIL::SigSpec(RTLIL::Sx);
                continue;
            }

            // Get the port connection and map it to unique SigBits
            const auto& orgSigSpec = a_Cell->getPort(port);
            const auto& orgSigBits = orgSigSpec.bits();

            RTLIL::SigSpec newSigSpec;
            for (size_t i=0; i<orgSigBits.size(); ++i) {
                auto newSigBit = m_SigMap(orgSigBits[i]);
                newSigSpec.append(newSigBit);
            }
       
            // Store
            config.connections[port] = newSigSpec;
        }

        return config;
    }

} QlDspSimdPass;

PRIVATE_NAMESPACE_END
