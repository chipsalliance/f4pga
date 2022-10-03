#include "kernel/register.h"
#include "kernel/rtlil.h"
#include "kernel/sigtools.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

// ============================================================================

struct DspFF : public Pass {

    /// A structure identifying specific pin in a cell instance
    struct CellPin {
        RTLIL::Cell *cell;    /// Cell pointer (nullptr for top-level ports)
        RTLIL::IdString port; /// Port name
        int bit;              /// Bit index

        CellPin(RTLIL::Cell *_cell, const RTLIL::IdString &_port, int _bit = 0) : cell(_cell), port(_port), bit(_bit) {}

        CellPin(const CellPin &ref) = default;
        CellPin(CellPin &&ref) = default;

        unsigned int hash() const
        {
            unsigned int h = 0;
            if (cell != nullptr) {
                h = mkhash_add(h, cell->hash());
            }
            h = mkhash_add(h, port.hash());
            h = mkhash_add(h, bit);
            return h;
        }

        bool operator==(const CellPin &ref) const { return (cell == ref.cell) && (port == ref.port) && (bit == ref.bit); }

        std::string as_string() const
        {
            if (cell != nullptr) {
                return stringf("%s.%s[%d]", RTLIL::unescape_id(cell->name).c_str(), RTLIL::unescape_id(port).c_str(), bit);
            } else {
                return stringf("%s[%d]", RTLIL::unescape_id(port).c_str(), bit);
            }
        }
    };

    // ..........................................

    /// Connection map
    struct ConnMap {

        /// Maps source SigBit to all sinks it drives CellPin.
        dict<RTLIL::SigBit, std::vector<CellPin>> sinks;
        /// Maps source SigBit to its driver CellPin
        dict<RTLIL::SigBit, CellPin> drivers;

        /// Builds the map
        void build(RTLIL::Module *module, const SigMap &sigmap)
        {
            clear();

            // Scan cell ports
            for (auto *cell : module->cells()) {
                for (const auto &it : cell->connections_) {
                    const auto &port = it.first;
                    const auto &sigbits = it.second.bits();
                    for (size_t i = 0; i < sigbits.size(); ++i) {
                        auto sigbit = sigmap(sigbits[i]);

                        // This is an input port (sink))
                        if (cell->input(port)) {
                            auto &vec = sinks[sigbit];
                            vec.push_back(CellPin(cell, port, i));
                        }
                        // This is a source
                        if (cell->output(port)) {
                            drivers.insert(std::make_pair(sigbit, CellPin(cell, port, i)));
                        }
                    }
                }
            }

            // Scan top-level ports
            for (auto &it : module->wires_) {
                auto *wire = it.second;

                if (!wire->port_input && !wire->port_output) {
                    continue;
                }

                RTLIL::SigSpec sigspec(wire, wire->start_offset, wire->width);
                const auto &sigbits = sigspec.bits();
                for (size_t i = 0; i < sigbits.size(); ++i) {
                    auto sigbit = sigbits[i];
                    if (!sigbit.wire) {
                        continue;
                    }

                    // Output port (sink)
                    if (sigbit.wire->port_output) {
                        auto &vec = sinks[sigmap(sigbit)];
                        vec.push_back(CellPin(nullptr, sigbit.wire->name, i));
                    }
                    // Input port (source)
                    if (sigbit.wire->port_input) {
                        drivers.insert(std::make_pair(sigbit, CellPin(nullptr, sigbit.wire->name, i)));
                    }
                }
            }
        }

        /// Clears the map
        void clear()
        {
            sinks.clear();
            drivers.clear();
        };
    };

    // ..........................................

    /// Describes a flip-flop type that can be integrated with a DSP cell
    struct FlopType {
        RTLIL::IdString name;

        /// A dict of port names indexed by their functions (like "clk", "rst")
        dict<RTLIL::IdString, RTLIL::IdString> ports;

        struct {
            /// A list of parameters that must match for all flip-flops
            std::vector<RTLIL::IdString> matching;
            /// A dict of parameter values that must match for a flip-flop
            dict<RTLIL::IdString, RTLIL::Const> required;
            /// A dict of parameters to be set in the DSP cell after integration
            dict<RTLIL::IdString, RTLIL::Const> set;
            /// A dict of parameters to be mapped to the DSP cell after integration
            dict<RTLIL::IdString, RTLIL::IdString> map;
        } params;
    };

    /// Describes a DSP cell port that has built-in register (flip-flops)
    struct PortType {
        RTLIL::IdString name;

        /// Range of port pins that have FFs (low to high, inclusive)
        std::pair<int, int> bits;
        /// A dict of associated cell ports indexed by their function (like "clk, "rst")
        /// along with the default value to connect when unused.
        dict<RTLIL::IdString, std::pair<RTLIL::IdString, RTLIL::Const>> assoc;
    };

    /// Describes a DSP register
    struct RegisterType {

        /// Control parameters
        struct {
            /// A dict of parameters to be set in the cell after integration
            dict<RTLIL::IdString, RTLIL::Const> set;
            /// A dict of parameters to be mapped to the cell after integration
            dict<RTLIL::IdString, RTLIL::IdString> map;
        } params;

        /// A list of ports to be connected to specific constants after flip-flop
        /// integration.
        dict<RTLIL::IdString, RTLIL::Const> connect;

        unsigned int hash() const
        {
            unsigned int h = 0;
            h = mkhash_add(h, params.set.hash());
            h = mkhash_add(h, params.map.hash());
            h = mkhash_add(h, connect.hash());
            return h;
        }

        bool operator==(const RegisterType &ref) const
        {
            return (params.set == ref.params.set) && (params.map == ref.params.map) && (connect == ref.connect);
        }
    };

    /// Describes a DSP cell type
    struct DspType {
        RTLIL::IdString name;
        dict<RegisterType, std::vector<PortType>> registers;
    };

    /// Describes a changes made to a DSP cell
    struct DspChanges {
        pool<RTLIL::IdString> params; // Modified params
        pool<RTLIL::IdString> conns;  // Altered connections (ports)
    };

    // ..........................................

    /// Describes unique flip-flop configuration that is exclusive.
    struct FlopData {
        RTLIL::IdString type;
        dict<RTLIL::IdString, RTLIL::SigBit> conns;
        struct {
            dict<RTLIL::IdString, RTLIL::Const> flop;
            dict<RTLIL::IdString, RTLIL::Const> dsp;
        } params;

        FlopData(const RTLIL::IdString &_type) : type(_type){};

        FlopData(const FlopData &ref) = default;
        FlopData(FlopData &&ref) = default;

        unsigned int hash() const
        {
            unsigned int h = 0;
            h = mkhash_add(h, type.hash());
            h = mkhash_add(h, conns.hash());
            h = mkhash_add(h, params.flop.hash());
            h = mkhash_add(h, params.dsp.hash());
            return h;
        }

        bool operator==(const FlopData &ref) const
        {
            return (type == ref.type) && (conns == ref.conns) && (params.flop == ref.params.flop) && (params.dsp == ref.params.dsp);
        }
    };

    // ..........................................

    /// Loads FF and DSP integration rules from a file
    void load_rules(const std::string &a_FileName)
    {

        // Parses a string and returns a vector of fields delimited by the
        // given character.
        auto getFields = [](const std::string &a_String, const char a_Delim = ' ', bool a_KeepEmpty = false) {
            std::vector<std::string> fields;
            std::stringstream ss(a_String);

            while (ss.good()) {
                std::string field;
                std::getline(ss, field, a_Delim);
                if (!field.empty() || a_KeepEmpty) {
                    fields.push_back(field);
                }
            }

            return fields;
        };

        // Parses a vector of strings like "<name>=<value>" starting from the
        // second one on the list
        auto parseNameValue = [&](const std::vector<std::string> &strs) {
            const std::regex expr("(\\S+)=(\\S+)");
            std::smatch match;

            std::vector<std::pair<std::string, std::string>> vec;

            for (size_t i = 1; i < strs.size(); ++i) {
                if (std::regex_match(strs[i], match, expr)) {
                    vec.push_back(std::make_pair(match[1], match[2]));
                } else {
                    log_error(" syntax error: '%s'\n", strs[i].c_str());
                }
            }

            return vec;
        };

        // Parses port name as "<name>[<hi>:<lo>]" or just "<name>"
        auto parsePortName = [&](const std::string &str) {
            const std::regex expr("^(.*)\\[([0-9]+):([0-9]+)\\]");
            std::smatch match;

            std::tuple<std::string, int, int> data;
            auto res = std::regex_match(str, match, expr);
            if (res) {
                data = std::make_tuple(std::string(match[1]), std::stoi(match[2]), std::stoi(match[3]));

                if ((std::get<2>(data) > std::get<1>(data)) || std::get<2>(data) < 0 || std::get<1>(data) < 0) {
                    log_error(" invalid port spec: '%s'\n", str.c_str());
                }
            } else {
                data = std::make_tuple(str, -1, -1);
            }

            return data;
        };

        std::ifstream file(a_FileName);
        std::string line;

        log("Loading rules from '%s'...\n", a_FileName.c_str());
        if (!file) {
            log_error(" Error opening file '%s'!\n", a_FileName.c_str());
        }

        // Parse each port as if it was associated with its own DSP register.
        // Group them each time a port definition is complete.
        PortType portType;
        RegisterType registerType;

        std::vector<DspType> dspTypes;
        std::vector<FlopType> flopTypes;

        std::vector<RTLIL::IdString> dspAliases;
        std::vector<std::string> portNames;

        std::vector<std::string> tok;

        // Parse the file
        while (1) {

            // Get line
            std::getline(file, line);
            if (!file) {
                break;
            }

            // Strip comment if any, skip empty lines
            size_t pos = line.find("#");
            if (pos != std::string::npos) {
                line = line.substr(0, pos);
            }
            if (line.find_first_not_of(" \r\n\t") == std::string::npos) {
                continue;
            }

            // Split the line
            const auto fields = getFields(line);
            log_assert(fields.size() >= 1);

            // DSP section
            if (fields[0] == "dsp") {
                if (fields.size() < 2) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (!tok.empty()) {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }
                tok.push_back(fields[0]);

                dspTypes.resize(dspTypes.size() + 1);
                dspTypes.back().name = RTLIL::escape_id(fields[1]);

                dspAliases.clear();
                for (size_t i = 2; i < fields.size(); ++i) {
                    dspAliases.push_back(RTLIL::escape_id(fields[i]));
                }
            } else if (fields[0] == "enddsp") {
                if (fields.size() != 1) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() != 1 || tok.back() != "dsp") {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }
                tok.pop_back();

                const auto dspType = dspTypes.back();

                for (const auto &alias : dspAliases) {
                    dspTypes.push_back(dspType);
                    dspTypes.back().name = alias;
                }
            }

            // DSP port section
            else if (fields[0] == "port") {
                if (fields.size() < 2) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() != 1 || tok.back() != "dsp") {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }
                tok.push_back(fields[0]);

                auto spec = parsePortName(fields[1]);

                portType = PortType();
                portType.name = RTLIL::escape_id(std::get<0>(spec));
                portType.bits = std::make_pair(std::get<2>(spec), std::get<1>(spec));
                portType.assoc.insert(std::make_pair(RTLIL::escape_id("clk"), std::make_pair(RTLIL::IdString(), RTLIL::Sx)));
                portType.assoc.insert(std::make_pair(RTLIL::escape_id("rst"), std::make_pair(RTLIL::IdString(), RTLIL::Sx)));
                portType.assoc.insert(std::make_pair(RTLIL::escape_id("ena"), std::make_pair(RTLIL::IdString(), RTLIL::Sx)));

                registerType = RegisterType();

                portNames.clear();
                for (size_t i = 2; i < fields.size(); ++i) {
                    portNames.push_back(fields[i]);
                }

            } else if (fields[0] == "endport") {
                if (fields.size() != 1) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() != 2 || tok.back() != "port") {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }
                tok.pop_back();

                // Store the DSP port
                auto &dspType = dspTypes.back();
                dspType.registers[registerType].push_back(portType);

                // Store any extra DSP ports belonging to the same register
                for (const auto &name : portNames) {
                    auto spec = parsePortName(name);

                    PortType portTypeCopy = portType;
                    portTypeCopy.name = RTLIL::escape_id(std::get<0>(spec));
                    portTypeCopy.bits = std::make_pair(std::get<2>(spec), std::get<1>(spec));

                    dspType.registers[registerType].push_back(portTypeCopy);
                }
            }

            // Flip-flop type section
            else if (fields[0] == "ff") {
                if (fields.size() != 2) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (!tok.empty()) {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }
                tok.push_back(fields[0]);

                flopTypes.resize(flopTypes.size() + 1);
                flopTypes.back().name = RTLIL::escape_id(fields[1]);
                flopTypes.back().ports.insert(std::make_pair(RTLIL::escape_id("clk"), RTLIL::IdString()));
                flopTypes.back().ports.insert(std::make_pair(RTLIL::escape_id("rst"), RTLIL::IdString()));
                flopTypes.back().ports.insert(std::make_pair(RTLIL::escape_id("ena"), RTLIL::IdString()));
                flopTypes.back().ports.insert(std::make_pair(RTLIL::escape_id("d"), RTLIL::IdString()));
                flopTypes.back().ports.insert(std::make_pair(RTLIL::escape_id("q"), RTLIL::IdString()));
            } else if (fields[0] == "endff") {
                if (fields.size() != 1) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() != 1 || tok.back() != "ff") {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }
                tok.pop_back();
            }

            // Signals
            else if (fields[0] == "clk") {
                if (tok.size() == 0 || (tok.back() != "port" && tok.back() != "ff")) {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }

                // Associated clock
                if (tok.back() == "port") {
                    if (fields.size() != 3) {
                        log_error(" syntax error: '%s'\n", line.c_str());
                    }
                    portType.assoc[RTLIL::escape_id("clk")] = std::make_pair(RTLIL::escape_id(fields[1]), RTLIL::Const::from_string(fields[2]));
                } else if (tok.back() == "ff") {
                    if (fields.size() != 2) {
                        log_error(" syntax error: '%s'\n", line.c_str());
                    }
                    flopTypes.back().ports[RTLIL::escape_id("clk")] = RTLIL::escape_id(fields[1]);
                }
            } else if (fields[0] == "rst") {
                if (tok.size() == 0 || (tok.back() != "port" && tok.back() != "ff")) {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }

                // Associated reset
                if (tok.back() == "port") {
                    if (fields.size() != 3) {
                        log_error(" syntax error: '%s'\n", line.c_str());
                    }
                    portType.assoc[RTLIL::escape_id("rst")] = std::make_pair(RTLIL::escape_id(fields[1]), RTLIL::Const::from_string(fields[2]));
                } else if (tok.back() == "ff") {
                    if (fields.size() != 2) {
                        log_error(" syntax error: '%s'\n", line.c_str());
                    }
                    flopTypes.back().ports[RTLIL::escape_id("rst")] = RTLIL::escape_id(fields[1]);
                }
            } else if (fields[0] == "ena") {
                if (tok.size() == 0 || (tok.back() != "port" && tok.back() != "ff")) {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }

                // Associated enable
                if (tok.back() == "port") {
                    if (fields.size() != 3) {
                        log_error(" syntax error: '%s'\n", line.c_str());
                    }
                    portType.assoc[RTLIL::escape_id("ena")] = std::make_pair(RTLIL::escape_id(fields[1]), RTLIL::Const::from_string(fields[2]));
                } else if (tok.back() == "ff") {
                    if (fields.size() != 2) {
                        log_error(" syntax error: '%s'\n", line.c_str());
                    }
                    flopTypes.back().ports[RTLIL::escape_id("ena")] = RTLIL::escape_id(fields[1]);
                }
            }

            else if (fields[0] == "d") {
                if (fields.size() != 2) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() == 0 || tok.back() != "ff") {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }

                flopTypes.back().ports[RTLIL::escape_id("d")] = RTLIL::escape_id(fields[1]);
            } else if (fields[0] == "q") {
                if (fields.size() != 2) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() == 0 || tok.back() != "ff") {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }

                flopTypes.back().ports[RTLIL::escape_id("q")] = RTLIL::escape_id(fields[1]);
            }

            // Parameters that must be set to certain values
            else if (fields[0] == "require") {
                if (fields.size() < 2) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() == 0 || tok.back() != "ff") {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }

                const auto vec = parseNameValue(fields);
                for (const auto &it : vec) {
                    flopTypes.back().params.required.insert(std::make_pair(RTLIL::escape_id(it.first), RTLIL::Const(it.second)));
                }
            }
            // Parameters that has to match for a flip-flop
            else if (fields[0] == "match") {
                if (fields.size() < 2) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() == 0 || tok.back() != "ff") {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }

                for (size_t i = 1; i < fields.size(); ++i) {
                    flopTypes.back().params.matching.push_back(RTLIL::escape_id(fields[i]));
                }
            }
            // Parameters to set
            else if (fields[0] == "set") {
                if (fields.size() < 2) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() == 0 || (tok.back() != "port" && tok.back() != "ff")) {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }

                const auto vec = parseNameValue(fields);
                dict<RTLIL::IdString, RTLIL::Const> set;
                for (const auto &it : vec) {
                    set.insert(std::make_pair(RTLIL::escape_id(it.first), RTLIL::Const(it.second)));
                }

                if (tok.back() == "port") {
                    registerType.params.set.swap(set);
                } else if (tok.back() == "ff") {
                    flopTypes.back().params.set.swap(set);
                }
            }
            // Parameters to copy / map
            else if (fields[0] == "map") {
                if (fields.size() < 2) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() == 0 || (tok.back() != "port" && tok.back() != "ff")) {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }

                const auto vec = parseNameValue(fields);
                dict<RTLIL::IdString, RTLIL::IdString> map;
                for (const auto &it : vec) {
                    map.insert(std::make_pair(RTLIL::escape_id(it.first), RTLIL::escape_id(it.second)));
                }

                if (tok.back() == "port") {
                    registerType.params.map.swap(map);
                } else if (tok.back() == "ff") {
                    flopTypes.back().params.map.swap(map);
                }
            }
            // Connections to make
            else if (fields[0] == "con") {
                if (fields.size() < 2) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() == 0 || tok.back() != "port") {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }

                const auto vec = parseNameValue(fields);
                for (const auto &it : vec) {
                    registerType.connect.insert(std::make_pair(RTLIL::escape_id(it.first), RTLIL::Const(it.second)));
                }
            }

            else {
                log_error(" unexpected keyword '%s'\n", fields[0].c_str());
            }
        }

        // Convert lists to maps
        for (const auto &it : dspTypes) {
            if (m_DspTypes.count(it.name)) {
                log_error(" duplicated rule for DSP '%s'\n", it.name.c_str());
            }
            m_DspTypes.insert(std::make_pair(it.name, it));
        }
        for (const auto &it : flopTypes) {
            if (m_FlopTypes.count(it.name)) {
                log_error(" duplicated rule for flip-flop '%s'\n", it.name.c_str());
            }
            m_FlopTypes.insert(std::make_pair(it.name, it));
        }
    }

    void dump_rules()
    {

        // Dump DSP types
        log("DSP types:\n");
        for (const auto &it1 : m_DspTypes) {
            const auto &dsp = it1.second;
            log(" %s\n", dsp.name.c_str());

            for (const auto &it2 : dsp.registers) {
                const auto &reg = it2.first;
                const auto &ports = it2.second;
                log(" ports:\n");
                for (const auto &port : ports) {

                    std::string range;
                    if (port.bits.first != -1 && port.bits.second != -1) {
                        range = stringf("[%d:%d]", port.bits.second, port.bits.first);
                    }

                    log("  %s.%s%s\n", dsp.name.c_str(), port.name.c_str(), range.c_str());

                    for (const auto &it : port.assoc) {
                        log("   %.3s: %s\n", it.first.c_str(), !it.second.first.empty() ? it.second.first.c_str() : "<none>");
                    }

                    if (!reg.params.set.empty()) {
                        log("   set params:\n");
                        for (const auto &it : reg.params.set) {
                            log("    %s=%s\n", it.first.c_str(), it.second.decode_string().c_str());
                        }
                    }
                    if (!reg.params.map.empty()) {
                        log("   map params:\n");
                        for (const auto &it : reg.params.map) {
                            log("    %s=%s\n", it.first.c_str(), it.second.c_str());
                        }
                    }
                    if (!reg.connect.empty()) {
                        log("   connect ports:\n");
                        for (const auto &it : reg.connect) {
                            log("    %s.%s=%s\n", dsp.name.c_str(), it.first.c_str(), it.second.as_string().c_str());
                        }
                    }
                }
            }
        }

        // Dump flop types
        log("Flip-flop types:\n");
        for (const auto &it : m_FlopTypes) {
            const auto &ff = it.second;
            log(" %s\n", ff.name.c_str());

            for (const auto &it : ff.ports) {
                log("  %.3s: %s\n", it.first.c_str(), !it.second.empty() ? it.second.c_str() : "<none>");
            }

            if (!ff.params.required.empty()) {
                log("  required params:\n");
                for (const auto &it : ff.params.required) {
                    log("   %s=%s\n", it.first.c_str(), it.second.decode_string().c_str());
                }
            }
            if (!ff.params.matching.empty()) {
                log("  params that must match:\n");
                for (const auto &it : ff.params.matching) {
                    log("   %s\n", it.c_str());
                }
            }
            if (!ff.params.set.empty()) {
                log("  set params:\n");
                for (const auto &it : ff.params.set) {
                    log("   %s=%s\n", it.first.c_str(), it.second.decode_string().c_str());
                }
            }
            if (!ff.params.map.empty()) {
                log("  map params:\n");
                for (const auto &it : ff.params.map) {
                    log("   %s=%s\n", it.first.c_str(), it.second.c_str());
                }
            }
        }
    }

    // ..........................................

    /// Temporary SigBit to SigBit helper map.
    SigMap m_SigMap;
    /// Module connection map
    ConnMap m_ConnMap;

    /// Cells to be removed (per module!)
    pool<RTLIL::Cell *> m_CellsToRemove;
    /// DSP cells that got changed
    dict<RTLIL::Cell *, DspChanges> m_DspChanges;

    /// DSP types
    dict<RTLIL::IdString, DspType> m_DspTypes;
    /// Flip-flop types
    dict<RTLIL::IdString, FlopType> m_FlopTypes;

    // ..........................................

    DspFF() : Pass("dsp_ff", "Integrates flip-flop into DSP blocks") {}

    void help() override
    {
        log("\n");
        log("    dsp_ff -rules <rules.txt> [selection]\n");
        log("\n");
        log("Integrates flip-flops with DSP blocks and enables their internal registers.\n");
        log("\n");
        log("The pass loads a set of rules from the file given with the '-rules' parameter.\n");
        log("The rules define what ports of a DSP module have internal registers and what\n");
        log("has to be done to enable them. They also define compatible flip-flop cell\n");
        log("types.\n");
        log("\n");
        log("The format of the rules file is the following:\n");
        log("\n");
        log("  # This is a comment\n");
        log("\n");
        log("  dsp <dsp_type> [<dsp_type> ...]\n");
        log("    port <dsp_port> [<dsp_port> ...]\n");
        log("      clk <associated clk> <default>\n");
        log("     [rst <associated reset>] <default>\n");
        log("     [ena <associated enable>] <default>\n");
        log("\n");
        log("     [set <param>=<value> [<param>=<value> ...]]\n");
        log("     [map <dsp_param>=<ff_param> [<dsp_param>=<ff_param> ...]]\n");
        log("     [con <port>=<const> [<port>=<const> ...]]\n");
        log("    endport\n");
        log("  enddsp\n");
        log("\n");
        log("  ff <ff_type>\n");
        log("    clk <clock input>\n");
        log("   [rst <reset input>]\n");
        log("   [ena <enable input>]\n");
        log("    d   <data input>\n");
        log("    q   <data output>\n");
        log("\n");
        log("    require <param>=<value> [<param>=<value> ...]\n");
        log("    match   <param> [<param> ...]\n");
        log("\n");
        log("    set <param>=<value> [<param>=<value> ...]\n");
        log("    map <dsp_param>=<ff_param> [<dsp_param>=<ff_param> ...]\n");
        log("  endff\n");
        log("\n");
        log("Each 'dsp' section defines a DSP cell type (can apply to multiple types).\n");
        log("Within it each 'port' section defines a data port with internal register.\n");
        log("There can be multiple port names given if they belong to the same control register.\n");
        log("The port can be specified as a whole (eg. 'DATA') or as a subset of the whole\n");
        log("(eg. 'DATA[7:0]').\n");
        log("\n");
        log("Statemenst 'clk', 'rst' and 'ena' define names of clock, reset and enable\n");
        log("ports associated with the data port along with default constant values to\n");
        log("connect them to when a given port has no counterpart in the flip-flop being\n");
        log("integrated.\n");
        log("\n");
        log("The 'set' statement tells how to set control parameter(s) of the DSP that\n");
        log("enable the input register on the port. The 'map' statement defines how to\n");
        log("map parameter(s) of the flip-flip being integrated to the DSP. Finally the\n");
        log("'con' statement informs how to connected control port(s) of the DSP to enable\n");
        log("the register.\n");
        log("\n");
        log("Each 'ff' section defines a flip-flop type that can be integrated into a DSP\n");
        log("cell. Inside this section 'clk', 'rst', 'ena', 'd' and 'q' define names of\n");
        log("clock, reset, enable, data in and data out ports of the flip-flop respectively.\n");
        log("\n");
        log("The 'require' statement defines parameter(s) that must have specific value\n");
        log("for a flip-flop to be considered for integration. The 'match' statement\n");
        log("lists names of flip-flop parameters that must match on all flip-flops connected\n");
        log("to a single DSP data port.\n");
        log("\n");
        log("The 'set' and 'map' statements serve the same function as in the DSP port\n");
        log("section but here they may differ depending on the flip-flop type being\n");
        log("integrated.\n");
    }

    void execute(std::vector<std::string> a_Args, RTLIL::Design *a_Design) override
    {
        log_header(a_Design, "Executing DSP_FF pass.\n");

        std::string rulesFile;

        // Parse args
        size_t argidx;
        for (argidx = 1; argidx < a_Args.size(); argidx++) {
            if (a_Args[argidx] == "-rules" && (argidx + 1) < a_Args.size()) {
                rulesFile = a_Args[++argidx];
                continue;
            }

            break;
        }
        extra_args(a_Args, argidx, a_Design);

        // Check args
        if (rulesFile.empty()) {
            log_cmd_error("No rules file specified!");
        }

        // Reset state
        m_CellsToRemove.clear();
        m_DspChanges.clear();
        m_DspTypes.clear();
        m_FlopTypes.clear();

        // Load rules
        rewrite_filename(rulesFile);
        load_rules(rulesFile);
        if (log_force_debug) {
            dump_rules();
        }

        // Process modules
        for (auto module : a_Design->selected_modules()) {

            // Setup the SigMap
            m_SigMap.clear();
            m_SigMap.set(module);

            // Build the connection map
            m_ConnMap.clear();
            m_ConnMap.build(module, m_SigMap);

            // Look for DSP cells
            for (auto cell : module->cells()) {

                // Not a DSP
                if (!m_DspTypes.count(cell->type)) {
                    continue;
                }

                // Process all registers
                auto &dspType = m_DspTypes.at(cell->type);
                for (auto &rule : dspType.registers) {
                    processRegister(cell, rule.first, rule.second);
                }
            }

            // Remove cells
            for (const auto &cell : m_CellsToRemove) {
                module->remove(cell);
            }
            m_CellsToRemove.clear();
        }

        // Clear maps
        m_SigMap.clear();
        m_ConnMap.clear();
    }

    // ..........................................

    bool checkFlop(RTLIL::Cell *a_Cell)
    {
        const auto &flopType = m_FlopTypes.at(a_Cell->type);
        bool isOk = true;

        log_debug("checking connected flip-flop '%s' of type '%s'... ", a_Cell->name.c_str(), a_Cell->type.c_str());

        // Must not have the "keep" attribute
        if (a_Cell->has_keep_attr()) {
            log_debug("\n   the 'keep' attribute is set");
            isOk = false;
        }

        // Check if required parameters are set as they should be
        for (const auto &it : flopType.params.required) {
            const auto curr = a_Cell->getParam(it.first);
            if (curr != it.second) {
                log_debug("\n   param '%s' mismatch ('%s' instead of '%s')", it.first.c_str(), curr.decode_string().c_str(),
                          it.second.decode_string().c_str());
                isOk = false;
            }
        }

        if (isOk) {
            log_debug("Ok\n");
        } else {
            log_debug("\n");
        }
        return isOk;
    }

    bool checkFlopDataAgainstDspRegister(const FlopData &a_FlopData, RTLIL::Cell *a_Cell, const RegisterType &a_Register,
                                         const std::vector<PortType> &a_Ports)
    {
        const auto &flopType = m_FlopTypes.at(a_FlopData.type);
        const auto &changes = m_DspChanges[a_Cell];
        bool isOk = true;

        log_debug("  checking connected flip-flop settings against the DSP register... ");

        // Check control signal connections
        for (const auto &port : a_Ports) {
            for (const auto &it : port.assoc) {
                const auto &key = it.first;
                const auto &port = it.second.first;

                SigBit conn(RTLIL::Sx);
                if (!port.empty() && a_Cell->hasPort(port)) {
                    auto sigspec = a_Cell->getPort(port);
                    auto sigbits = sigspec.bits();
                    log_assert(sigbits.size() <= 1);
                    if (!sigbits.empty()) {
                        conn = m_SigMap(sigbits[0]);
                    }
                }

                if (conn.is_wire() || (!conn.is_wire() && conn.data != RTLIL::Sx)) {
                    if (conn != a_FlopData.conns.at(key)) {
                        log_debug("\n   connection to port '%s' mismatch", port.c_str());
                        isOk = false;
                    }
                }
            }
        }

        auto checkParam = [&](const RTLIL::IdString &name, const RTLIL::Const &curr, const RTLIL::Const &next) {
            if (curr != next && changes.params.count(name)) {
                log_debug("\n   the param '%s' mismatch ('%s' instead of '%s')", name.c_str(), curr.decode_string().c_str(),
                          next.decode_string().c_str());
                isOk = false;
                return false;
            }
            return true;
        };

        // Check parameters to be mapped (by the port rule)
        for (const auto &it : a_Register.params.map) {
            if (a_Cell->hasParam(it.first) && a_FlopData.params.dsp.count(it.second)) {
                const auto curr = a_Cell->getParam(it.first);
                const auto flop = a_FlopData.params.dsp.at(it.second);
                checkParam(it.first, curr, flop);
            }
        }

        // Check parameters to be set (by the port rule)
        for (const auto &it : a_Register.params.set) {
            if (a_Cell->hasParam(it.first)) {
                const auto curr = a_Cell->getParam(it.first);
                checkParam(it.first, curr, it.second);
            }
        }

        // Check parameters to be mapped (by the flip-flop rule)
        for (const auto &it : flopType.params.map) {
            if (a_Cell->hasParam(it.first) && a_FlopData.params.dsp.count(it.second)) {
                const auto curr = a_Cell->getParam(it.first);
                const auto flop = a_FlopData.params.dsp.at(it.second);
                checkParam(it.first, curr, flop);
            }
        }

        // Check parameters to be set (by the flip-flop rule)
        for (const auto &it : flopType.params.set) {
            if (a_Cell->hasParam(it.first)) {
                const auto curr = a_Cell->getParam(it.first);
                checkParam(it.first, curr, it.second);
            }
        }

        if (isOk) {
            log_debug("Ok\n");
        } else {
            log_debug("\n");
        }
        return isOk;
    }

    /// Returns a string with either wire name or constant value for a SigBit
    static std::string sigBitName(const RTLIL::SigBit &a_SigBit)
    {
        if (a_SigBit.is_wire()) {
            RTLIL::Wire *w = a_SigBit.wire;
            return RTLIL::unescape_id(w->name);
        } else {
            switch (a_SigBit.data) {
            case RTLIL::State::S0:
                return "1'b0";
            case RTLIL::State::S1:
                return "1'b1";
            case RTLIL::State::Sx:
                return "1'bx";
            case RTLIL::State::Sz:
                return "1'bz";
            case RTLIL::State::Sa:
                return "-";
            case RTLIL::State::Sm:
                return "m";
            }
            return "?";
        }
    }

    // ..........................................

    void processRegister(RTLIL::Cell *a_Cell, const RegisterType &a_Register, const std::vector<PortType> &a_Ports)
    {

        // The cell register control parameter(s) must not be set
        for (const auto &it : a_Register.params.set) {
            const auto curr = a_Cell->getParam(it.first);
            if (curr == it.second) {
                log_debug(" the param '%s' is already set to '%s'\n", it.first.c_str(), it.second.decode_string().c_str());
                return;
            }
        }

        pool<FlopData> groups;
        dict<RTLIL::IdString, std::vector<RTLIL::Cell *>> flops;

        // Process ports
        bool flopsOk = true;
        for (const auto &port : a_Ports) {
            log_debug(" attempting flip-flop integration for %s.%s of %s\n", a_Cell->type.c_str(), port.name.c_str(), a_Cell->name.c_str());

            if (!a_Cell->hasPort(port.name)) {
                log_debug("  port unconnected.\n");
                continue;
            }
            log_assert(a_Cell->output(port.name) || a_Cell->input(port.name));

            // Get port connections
            auto sigspec = a_Cell->getPort(port.name);
            auto sigbits = sigspec.bits();

            flops[port.name] = std::vector<RTLIL::Cell *>(sigbits.size(), nullptr);
            for (size_t i = 0; i < sigbits.size(); ++i) {
                auto sigbit = m_SigMap(sigbits[i]);

                log_debug("  %2zu. ", i);

                // Port connected to a const.
                if (!sigbit.wire) {
                    log_debug("constant\n");
                    continue;
                }

                // Skip bits out of the specified range
                if ((port.bits.first >= 0 && (int)i < port.bits.first) || (port.bits.second >= 0 && (int)i > port.bits.second)) {
                    log_debug("(excluded)\n");
                    continue;
                }

                pool<CellPin> others;

                // Get sinks(s), discard the port completely if more than one sink
                // is found.
                if (a_Cell->output(port.name)) {
                    if (m_ConnMap.sinks.count(sigbit)) {
                        for (const auto &sink : m_ConnMap.sinks.at(sigbit)) {
                            if (sink.cell != nullptr && m_CellsToRemove.count(sink.cell)) {
                                continue;
                            }
                            others.insert(sink);
                        }
                    }

                }
                // Get driver. Discard if the driver drives something else too
                else if (a_Cell->input(port.name)) {
                    if (m_ConnMap.drivers.count(sigbit)) {
                        auto driver = m_ConnMap.drivers.at(sigbit);

                        if (m_ConnMap.sinks.count(sigbit)) {
                            auto sinks = m_ConnMap.sinks.at(sigbit);
                            if (sinks.size() > 1) {
                                log_debug("multiple sinks (%zu)\n", others.size());
                                flopsOk = false;
                                continue;
                            }
                        }

                        others.insert(driver);
                    }
                }

                // No others - unconnected
                if (others.empty()) {
                    log_debug("unconnected\n");
                    continue;
                }

                if (others.size() > 1) {
                    log_debug("multiple sinks (%zu)\n", others.size());
                    flopsOk = false;
                    continue;
                }

                // Get the sink, check if this is a flip-flop
                auto &other = *others.begin();
                auto *flop = other.cell;

                if (flop == nullptr) {
                    if (!other.port.empty()) {
                        log_debug("connection reaches module edge\n");
                        flopsOk = false;
                    }
                    log_debug("unconnected\n");
                    continue;
                }

                if (!m_FlopTypes.count(flop->type)) {
                    log_debug("non-flip-flop connected\n");
                    flopsOk = false;
                    continue;
                }

                // Check if the connection goes to the data input/output port
                const auto &flopType = m_FlopTypes.at(flop->type);
                RTLIL::IdString flopPort;
                if (a_Cell->output(port.name)) {
                    flopPort = flopType.ports.at(RTLIL::escape_id("d"));
                } else if (a_Cell->input(port.name)) {
                    flopPort = flopType.ports.at(RTLIL::escape_id("q"));
                }

                if (flopPort != other.port) {
                    log_debug("connection to non-data port of a flip-flip");
                    flopsOk = false;
                    continue;
                }

                // Check the flip-flop configuration
                if (!checkFlop(flop)) {
                    flopsOk = false;
                    continue;
                }

                // Get parameters to be mapped to the DSP according to the port
                // rule.
                dict<RTLIL::IdString, RTLIL::Const> mappedParams;
                for (const auto &it : a_Register.params.map) {
                    if (flop->hasParam(it.second)) {
                        const auto &value = flop->getParam(it.second);
                        mappedParams.insert(std::make_pair(it.first, value));
                    }
                }

                // Store the flop and its data
                groups.insert(getFlopData(flop, mappedParams));
                flops[port.name][i] = flop;
            }
        }

        // Cannot integrate for various reasons
        if (!flopsOk) {
            log_debug(" cannot use the DSP register\n");
            return;
        }

        // No matching flip-flop groups
        if (groups.empty()) {
            log_debug(" no matching flip-flops found\n");
            return;
        }

        // Do not allow more than a single group
        if (groups.size() != 1) {
            log_debug(" %zu flip-flop groups, only a single one allowed\n", groups.size());
            return;
        }

        // Validate the flip flop data agains the DSP cell
        const auto &flopData = *groups.begin();
        if (!checkFlopDataAgainstDspRegister(flopData, a_Cell, a_Register, a_Ports)) {
            log_debug(" flip-flops vs. DSP check failed\n");
            return;
        }

        // Log connections
        for (const auto &port : a_Ports) {

            if (!flops.count(port.name)) {
                continue;
            }

            log(" %s %s.%s\n", a_Cell->type.c_str(), a_Cell->name.c_str(), port.name.c_str());

            const auto &conns = flops.at(port.name);
            for (size_t i = 0; i < conns.size(); ++i) {
                if (conns[i] != nullptr) {
                    log_debug("  %2zu. %s %s\n", i, conns[i]->type.c_str(), conns[i]->name.c_str());
                } else if ((port.bits.first >= 0 && (int)i < port.bits.first) || (port.bits.second >= 0 && (int)i > port.bits.second)) {
                    log_debug("  %2zu. (excluded)\n", i);
                } else {
                    log_debug("  %2zu. None\n", i);
                }
            }
        }

        // Reconnect data signals, mark the flip-flop for removal
        const auto &flopType = m_FlopTypes.at(flopData.type);
        for (const auto &port : a_Ports) {

            if (!flops.count(port.name)) {
                continue;
            }

            const auto &conns = flops.at(port.name);
            auto sigspec = a_Cell->getPort(port.name);
            auto sigbits = sigspec.bits();

            for (size_t i = 0; i < conns.size(); ++i) {

                auto *flop = conns[i];
                if (flop == nullptr) {
                    continue;
                }

                RTLIL::IdString flopPort;
                if (a_Cell->output(port.name)) {
                    flopPort = flopType.ports.at(RTLIL::escape_id("q"));
                } else if (a_Cell->input(port.name)) {
                    flopPort = flopType.ports.at(RTLIL::escape_id("d"));
                }

                if (!flop->hasPort(flopPort)) {
                    log_error("cell '%s' does not have port '%s'!\n", flop->type.c_str(), flopPort.c_str());
                }

                sigbits[i] = SigBit(RTLIL::Sx);
                auto sigspec = flop->getPort(flopPort);
                log_assert(sigspec.bits().size() <= 1);
                if (sigspec.bits().size() == 1) {
                    sigbits[i] = sigspec.bits()[0];
                }

                m_CellsToRemove.insert(flop);
            }

            a_Cell->setPort(port.name, RTLIL::SigSpec(sigbits));
        }

        // Reconnect (map) control signals. Connect the default value if
        // a particular signal is not present in the flip-flop.
        for (const auto &port : a_Ports) {
            for (const auto &it : port.assoc) {
                const auto &key = it.first;
                const auto &port = it.second.first;

                auto conn = RTLIL::SigBit(RTLIL::SigChunk(it.second.second));
                if (flopData.conns.count(key)) {
                    conn = flopData.conns.at(key);
                }

                log_debug(" connecting %s.%s to %s\n", a_Cell->type.c_str(), port.c_str(), sigBitName(conn).c_str());
                a_Cell->setPort(port, conn);
                m_DspChanges[a_Cell].conns.insert(port);
            }
        }

        // Connect control signals according to the register rule
        for (const auto &it : a_Register.connect) {
            log_debug(" connecting %s.%s to %s\n", a_Cell->type.c_str(), it.first.c_str(), it.second.as_string().c_str());
            a_Cell->setPort(it.first, it.second);
            m_DspChanges[a_Cell].conns.insert(it.first);
        }

        // Map parameters (register rule)
        for (const auto &it : a_Register.params.map) {
            if (flopData.params.dsp.count(it.second)) {
                const auto &param = flopData.params.dsp.at(it.second);
                log_debug(" setting param '%s' to '%s'\n", it.first.c_str(), param.decode_string().c_str());
                a_Cell->setParam(it.first, param);
                m_DspChanges[a_Cell].params.insert(it.first);
            }
        }

        // Map parameters (flip-flop rule)
        for (const auto &it : flopType.params.map) {
            if (flopData.params.dsp.count(it.second)) {
                const auto &param = flopData.params.dsp.at(it.second);
                log_debug(" setting param '%s' to '%s'\n", it.first.c_str(), param.decode_string().c_str());
                a_Cell->setParam(it.first, param);
                m_DspChanges[a_Cell].params.insert(it.first);
            }
        }

        // Set parameters (port rule)
        for (const auto &it : a_Register.params.set) {
            log_debug(" setting param '%s' to '%s'\n", it.first.c_str(), it.second.decode_string().c_str());
            a_Cell->setParam(it.first, it.second);
            m_DspChanges[a_Cell].params.insert(it.first);
        }

        // Set parameters (flip-flop rule)
        for (const auto &it : flopType.params.set) {
            log_debug(" setting param '%s' to '%s'\n", it.first.c_str(), it.second.decode_string().c_str());
            a_Cell->setParam(it.first, it.second);
            m_DspChanges[a_Cell].params.insert(it.first);
        }
    }

    // ..........................................

    /// Collects flip-flop connectivity data and parameters which defines the
    /// group it belongs to.
    FlopData getFlopData(RTLIL::Cell *a_Cell, const dict<RTLIL::IdString, RTLIL::Const> &a_ExtraParams)
    {
        FlopData data(a_Cell->type);

        log_assert(m_FlopTypes.count(a_Cell->type) != 0);
        const auto &flopType = m_FlopTypes.at(a_Cell->type);

        // Gather connections to control ports
        for (const auto &it : flopType.ports) {

            // Skip "D" and "Q" as they connection will always differ.
            if (it.first == RTLIL::escape_id("d") || it.first == RTLIL::escape_id("q")) {
                continue;
            }

            if (!it.second.empty() && a_Cell->hasPort(it.second)) {
                auto sigspec = a_Cell->getPort(it.second);
                auto sigbits = sigspec.bits();
                log_assert(sigbits.size() <= 1);
                if (!sigbits.empty()) {
                    data.conns[it.first] = m_SigMap(sigbits[0]);
                }
            }
        }

        // Gather flip-flop parameters that need to match
        for (const auto &it : flopType.params.matching) {
            log_assert(a_Cell->hasParam(it));
            data.params.flop.insert(std::make_pair(it, a_Cell->getParam(it)));
        }

        // Gather flip-flop parameters to be mapped to the DSP as well
        for (const auto &it : flopType.params.map) {
            log_assert(a_Cell->hasParam(it.second));
            data.params.flop.insert(std::make_pair(it.second, a_Cell->getParam(it.second)));
        }

        // Gather DSP parameters and their values to be set to too
        for (const auto &it : flopType.params.set) {
            data.params.dsp.insert(it);
        }

        // Append extra DSP parameters
        for (const auto &it : a_ExtraParams) {
            data.params.dsp.insert(it);
        }

        return data;
    }

} DspFF;

PRIVATE_NAMESPACE_END
