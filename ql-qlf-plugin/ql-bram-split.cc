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

struct QlBramSplitPass : public Pass {

    QlBramSplitPass() : Pass("ql_bram_split", "Infers QuickLogic k6n10f BRAM pairs that can operate independently") {}

    void help() override
    {
        log("\n");
        log("    ql_bram_split [selection]\n");
        log("\n");
        log("    This pass identifies k6n10f 18K BRAM cells\n");
        log("    and packs pairs of them together into final TDP36K cell that can\n");
        log("    be split into 2x18K BRAMs.\n");
    }

    // ..........................................

    /// Describes BRAM config unique to a whole BRAM cell
    struct BramConfig {

        // Port connections
        dict<RTLIL::IdString, RTLIL::SigSpec> connections;

        // TODO: Possibly include parameters here. For now we have just
        // connections.

        BramConfig() = default;

        BramConfig(const BramConfig &ref) = default;
        BramConfig(BramConfig &&ref) = default;

        unsigned int hash() const { return connections.hash(); }

        bool operator==(const BramConfig &ref) const { return connections == ref.connections; }
    };

    // ..........................................

    // BRAM control and config ports to consider and how to map them to ports
    // of the target BRAM cell
    const std::vector<std::pair<std::string, std::string>> m_BramSharedPorts = {};
    // BRAM parameters
    const std::vector<std::string> m_BramParams = {"CFG_ABITS", "CFG_DBITS"};

    // TDP BRAM 1x18 data ports for subcell #1 and how to map them to ports of the target TDP BRAM 2x18 cell
    const std::vector<std::pair<std::string, std::string>> m_BramTDPDataPorts_0 = {
      std::make_pair("A1ADDR", "A1ADDR"), std::make_pair("A1DATA", "A1DATA"), std::make_pair("A1EN", "A1EN"),     std::make_pair("B1ADDR", "B1ADDR"),
      std::make_pair("B1DATA", "B1DATA"), std::make_pair("B1EN", "B1EN"),     std::make_pair("C1ADDR", "C1ADDR"), std::make_pair("C1DATA", "C1DATA"),
      std::make_pair("C1EN", "C1EN"),     std::make_pair("CLK1", "CLK1"),     std::make_pair("CLK2", "CLK2"),     std::make_pair("D1ADDR", "D1ADDR"),
      std::make_pair("D1DATA", "D1DATA"), std::make_pair("D1EN", "D1EN")};
    // TDP BRAM 1x18 data ports for subcell #2 and how to map them to ports of the target TDP BRAM 2x18 cell
    const std::vector<std::pair<std::string, std::string>> m_BramTDPDataPorts_1 = {
      std::make_pair("A1ADDR", "E1ADDR"), std::make_pair("A1DATA", "E1DATA"), std::make_pair("A1EN", "E1EN"),     std::make_pair("B1ADDR", "F1ADDR"),
      std::make_pair("B1DATA", "F1DATA"), std::make_pair("B1EN", "F1EN"),     std::make_pair("C1ADDR", "G1ADDR"), std::make_pair("C1DATA", "G1DATA"),
      std::make_pair("C1EN", "G1EN"),     std::make_pair("CLK1", "CLK3"),     std::make_pair("CLK2", "CLK4"),     std::make_pair("D1ADDR", "H1ADDR"),
      std::make_pair("D1DATA", "H1DATA"), std::make_pair("D1EN", "H1EN")};
    // Source BRAM TDP cell type (1x18K)
    const std::string m_Bram1x18TDPType = "$__QLF_FACTOR_BRAM18_TDP";
    // Target BRAM TDP cell type for the split mode
    const std::string m_Bram2x18TDPType = "BRAM2x18_TDP";

    // SDP BRAM 1x18 data ports for subcell #1 and how to map them to ports of the target SDP BRAM 2x18 cell
    const std::vector<std::pair<std::string, std::string>> m_BramSDPDataPorts_0 = {
      std::make_pair("A1ADDR", "A1ADDR"), std::make_pair("A1DATA", "A1DATA"), std::make_pair("A1EN", "A1EN"), std::make_pair("B1ADDR", "B1ADDR"),
      std::make_pair("B1DATA", "B1DATA"), std::make_pair("B1EN", "B1EN"),     std::make_pair("CLK1", "CLK1")};
    // SDP BRAM 1x18 data ports for subcell #2 and how to map them to ports of the target SDP BRAM 2x18 cell
    const std::vector<std::pair<std::string, std::string>> m_BramSDPDataPorts_1 = {
      std::make_pair("A1ADDR", "C1ADDR"), std::make_pair("A1DATA", "C1DATA"), std::make_pair("A1EN", "C1EN"), std::make_pair("B1ADDR", "D1ADDR"),
      std::make_pair("B1DATA", "D1DATA"), std::make_pair("B1EN", "D1EN"),     std::make_pair("CLK1", "CLK2")};
    // Source BRAM SDP cell type (1x18K)
    const std::string m_Bram1x18SDPType = "$__QLF_FACTOR_BRAM18_SDP";
    // Target BRAM SDP cell type for the split mode
    const std::string m_Bram2x18SDPType = "BRAM2x18_SDP";

    /// Temporary SigBit to SigBit helper map.
    SigMap m_SigMap;

    // ..........................................

    void map_ports(const std::vector<std::pair<std::string, std::string>> mapping, const RTLIL::Cell *bram_1x18, RTLIL::Cell *bram_2x18)
    {
        for (const auto &it : mapping) {
            auto src = RTLIL::escape_id(it.first);
            auto dst = RTLIL::escape_id(it.second);

            size_t width;
            bool isOutput;

            std::tie(width, isOutput) = getPortInfo(bram_2x18, dst);

            auto getConnection = [&](const RTLIL::Cell *cell) {
                RTLIL::SigSpec sigspec;
                if (cell->hasPort(src)) {
                    const auto &sig = cell->getPort(src);
                    sigspec.append(sig);
                }
                if (sigspec.bits().size() < width / 2) {
                    if (isOutput) {
                        for (size_t i = 0; i < width / 2 - sigspec.bits().size(); ++i) {
                            sigspec.append(RTLIL::SigSpec());
                        }
                    } else {
                        sigspec.append(RTLIL::SigSpec(RTLIL::Sx, width / 2 - sigspec.bits().size()));
                    }
                }
                return sigspec;
            };

            RTLIL::SigSpec sigspec;
            sigspec.append(getConnection(bram_1x18));
            bram_2x18->setPort(dst, sigspec);
        }
    }

    void execute(std::vector<std::string> a_Args, RTLIL::Design *a_Design) override
    {
        log_header(a_Design, "Executing QL_BRAM_Split pass.\n");

        // Parse args
        extra_args(a_Args, 1, a_Design);

        // Process modules
        for (auto module : a_Design->selected_modules()) {

            // Setup the SigMap
            m_SigMap.clear();
            m_SigMap.set(module);

            // Assemble BRAM cell groups
            dict<BramConfig, std::vector<RTLIL::Cell *>> groups;
            for (auto cell : module->selected_cells()) {

                // Check if this is a BRAM cell
                if (cell->type != RTLIL::escape_id(m_Bram1x18TDPType) && cell->type != RTLIL::escape_id(m_Bram1x18SDPType)) {
                    continue;
                }

                // Skip if it has the (* keep *) attribute set
                if (cell->has_keep_attr()) {
                    continue;
                }

                // Add to a group
                const auto key = getBramConfig(cell);
                groups[key].push_back(cell);
            }

            std::vector<const RTLIL::Cell *> cellsToRemove;

            // Map cell pairs to the target BRAM 2x18 cell
            for (const auto &it : groups) {
                const auto &group = it.second;
                const auto &config = it.first;

                // Ensure an even number
                size_t count = group.size();
                if (count & 1)
                    count--;

                // Map SIMD pairs
                for (size_t i = 0; i < count; i += 2) {
                    const RTLIL::Cell *bram_0 = group[i];
                    const RTLIL::Cell *bram_1 = group[i + 1];

                    if (bram_0->type != bram_1->type)
                        log_error("Unsupported BRAM configuration: one half of TDP36K is TDP, second SDP");

                    std::vector<std::pair<std::string, std::string>> m_BramDataPorts_0;
                    std::vector<std::pair<std::string, std::string>> m_BramDataPorts_1;
                    std::string m_Bram1x18Type;
                    std::string m_Bram2x18Type;
                    // Distinguish between TDP and SDP
                    if (bram_0->type == RTLIL::escape_id(m_Bram1x18TDPType)) {
                        m_BramDataPorts_0 = m_BramTDPDataPorts_0;
                        m_BramDataPorts_1 = m_BramTDPDataPorts_1;
                        m_Bram1x18Type = m_Bram1x18TDPType;
                        m_Bram2x18Type = m_Bram2x18TDPType;
                    } else {
                        m_BramDataPorts_0 = m_BramSDPDataPorts_0;
                        m_BramDataPorts_1 = m_BramSDPDataPorts_1;
                        m_Bram1x18Type = m_Bram1x18SDPType;
                        m_Bram2x18Type = m_Bram2x18SDPType;
                    }

                    std::string name = stringf("bram_%s_%s", RTLIL::unescape_id(bram_0->name).c_str(), RTLIL::unescape_id(bram_1->name).c_str());

                    log(" BRAM: %s (%s) + %s (%s) => %s (%s)\n", RTLIL::unescape_id(bram_0->name).c_str(), RTLIL::unescape_id(bram_0->type).c_str(),
                        RTLIL::unescape_id(bram_1->name).c_str(), RTLIL::unescape_id(bram_1->type).c_str(), RTLIL::unescape_id(name).c_str(),
                        m_Bram2x18Type.c_str());

                    // Create the new cell
                    RTLIL::Cell *bram_2x18 = module->addCell(RTLIL::escape_id(name), RTLIL::escape_id(m_Bram2x18Type));

                    // Check if the target cell is known (important to know
                    // its port widths)
                    if (!bram_2x18->known()) {
                        log_error(" The target cell type '%s' is not known!", m_Bram2x18Type.c_str());
                    }

                    // Connect shared ports
                    for (const auto &it : m_BramSharedPorts) {
                        auto src = RTLIL::escape_id(it.first);
                        auto dst = RTLIL::escape_id(it.second);

                        bram_2x18->setPort(dst, config.connections.at(src));
                    }

                    // Connect data ports
                    // Connect first bram
                    map_ports(m_BramDataPorts_0, bram_0, bram_2x18);
                    // Connect second bram
                    map_ports(m_BramDataPorts_1, bram_1, bram_2x18);

                    // Set bram parameters
                    for (const auto &it : m_BramParams) {
                        auto val = bram_0->getParam(RTLIL::escape_id(it));
                        bram_2x18->setParam(RTLIL::escape_id(it), val);
                    }

                    // Setting manual parameters
                    if (bram_0->type == RTLIL::escape_id(m_Bram1x18TDPType)) {
                        bram_2x18->setParam(RTLIL::escape_id("CFG_ENABLE_B"), bram_0->getParam(RTLIL::escape_id("CFG_ENABLE_B")));
                        bram_2x18->setParam(RTLIL::escape_id("CFG_ENABLE_D"), bram_0->getParam(RTLIL::escape_id("CFG_ENABLE_D")));
                        bram_2x18->setParam(RTLIL::escape_id("CFG_ENABLE_F"), bram_1->getParam(RTLIL::escape_id("CFG_ENABLE_B")));
                        bram_2x18->setParam(RTLIL::escape_id("CFG_ENABLE_H"), bram_1->getParam(RTLIL::escape_id("CFG_ENABLE_D")));
                    } else {
                        bram_2x18->setParam(RTLIL::escape_id("CFG_ENABLE_B"), bram_0->getParam(RTLIL::escape_id("CFG_ENABLE_B")));
                        bram_2x18->setParam(RTLIL::escape_id("CFG_ENABLE_D"), bram_1->getParam(RTLIL::escape_id("CFG_ENABLE_B")));
                    }
                    if (bram_0->hasParam(RTLIL::escape_id("INIT")))
                        bram_2x18->setParam(RTLIL::escape_id("INIT0"), bram_0->getParam(RTLIL::escape_id("INIT")));
                    if (bram_1->hasParam(RTLIL::escape_id("INIT")))
                        bram_2x18->setParam(RTLIL::escape_id("INIT1"), bram_1->getParam(RTLIL::escape_id("INIT")));

                    // Mark BRAM parts for removal
                    cellsToRemove.push_back(bram_0);
                    cellsToRemove.push_back(bram_1);
                }
            }

            // Remove old cells
            for (const auto &cell : cellsToRemove) {
                module->remove(const_cast<RTLIL::Cell *>(cell));
            }
        }

        // Clear
        m_SigMap.clear();
    }

    // ..........................................

    /// Looks up port width and direction in the cell definition and returns it.
    /// Returns (0, false) if it cannot be determined.
    std::pair<size_t, bool> getPortInfo(RTLIL::Cell *a_Cell, RTLIL::IdString a_Port)
    {
        if (!a_Cell->known()) {
            return std::make_pair(0, false);
        }

        // Get the module defining the cell (the previous condition ensures
        // that the pointers are valid)
        RTLIL::Module *mod = a_Cell->module->design->module(a_Cell->type);
        if (mod == nullptr) {
            return std::make_pair(0, false);
        }

        // Get the wire representing the port
        RTLIL::Wire *wire = mod->wire(a_Port);
        if (wire == nullptr) {
            return std::make_pair(0, false);
        }

        return std::make_pair(wire->width, wire->port_output);
    }

    /// Given a BRAM cell populates and returns a BramConfig struct for it.
    BramConfig getBramConfig(RTLIL::Cell *a_Cell)
    {
        BramConfig config;

        for (const auto &it : m_BramSharedPorts) {
            auto port = RTLIL::escape_id(it.first);

            // Port unconnected
            if (!a_Cell->hasPort(port)) {
                config.connections[port] = RTLIL::SigSpec(RTLIL::Sx);
                continue;
            }

            // Get the port connection and map it to unique SigBits
            const auto &orgSigSpec = a_Cell->getPort(port);
            const auto &orgSigBits = orgSigSpec.bits();

            RTLIL::SigSpec newSigSpec;
            for (size_t i = 0; i < orgSigBits.size(); ++i) {
                auto newSigBit = m_SigMap(orgSigBits[i]);
                newSigSpec.append(newSigBit);
            }

            // Store
            config.connections[port] = newSigSpec;
        }

        return config;
    }

} QlBramSplitPass;

PRIVATE_NAMESPACE_END
