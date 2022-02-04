#include "kernel/register.h"
#include "kernel/rtlil.h"
#include "kernel/sigtools.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

// ============================================================================

struct DspFF : public Pass {

    /// A structure identifying specific pin in a cell instance
    struct CellPin {
        RTLIL::Cell*    cell;   /// Cell pointer (nullptr for top-level ports)
        RTLIL::IdString port;   /// Port name
        int             bit;    /// Bit index

        CellPin (RTLIL::Cell* _cell,
                 const RTLIL::IdString& _port,
                 int _bit = 0) : 
            cell(_cell),
            port(_port),
            bit (_bit)
        {}

        CellPin (const CellPin& ref) = default;
        CellPin (CellPin&& ref) = default;

        unsigned int hash () const {
            unsigned int h = 0;
            if (cell != nullptr) {
                h = mkhash_add(h, cell->hash());
            }
            h = mkhash_add(h, port.hash());
            h = mkhash_add(h, bit);
            return h;
        }

        bool operator == (const CellPin& ref) const {
            return  (cell == ref.cell) &&
                    (port == ref.port) &&
                    (bit  == ref.bit);
        }
    };

    // ..........................................

    struct FlopType {
        RTLIL::IdString name;

        struct {
            RTLIL::IdString clk;
            RTLIL::IdString rst;
            RTLIL::IdString ena;
            RTLIL::IdString d;
            RTLIL::IdString q;
        } ports;

        struct {
            std::vector<RTLIL::IdString>           matching;
            dict<RTLIL::IdString, RTLIL::Const>    required;
            dict<RTLIL::IdString, RTLIL::Const>    set;
            dict<RTLIL::IdString, RTLIL::IdString> map;
        } params;
    };

    struct DspPortType {
        RTLIL::IdString name;

        struct {
            RTLIL::IdString clk;
            RTLIL::IdString rst;
            RTLIL::IdString ena;
        } assoc;

        struct {
            dict<RTLIL::IdString, RTLIL::Const>    set;
            dict<RTLIL::IdString, RTLIL::IdString> map;
        } params;

        dict<RTLIL::IdString, RTLIL::Const> connect;
    };

    struct DspType {
        RTLIL::IdString name;
        std::vector<DspPortType> ports;
    };

    // ..........................................

    void load_rules(const std::string& a_FileName) {

        // Parses a vector of strings like "<name>=<value>" starting from the
        // second one on the list
        auto parseNameValue = [&](const std::vector<std::string>& strs) {
            const std::regex expr ("(\\S+)=(\\S+)");
            std::smatch      match;

            std::vector<std::pair<std::string, std::string>> vec;

            for (size_t i=1; i<strs.size(); ++i) {
                if (std::regex_match(strs[i], match, expr)) {
                    vec.push_back(std::make_pair(match[1], match[2]));
                }
                else {
                    log_error(" syntax error: '%s'\n", strs[i].c_str());
                }
            }

            return vec;
        };

        std::ifstream file (a_FileName);
        std::string line;

        log("Loading rules from '%s'...\n", a_FileName.c_str());
        if (!file) {
            log_error(" Error opening file!\n");
        }

        std::vector<DspType>    dspTypes;
        std::vector<FlopType>   flopTypes;

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
            const auto fields = get_fields(line);
            log_assert(fields.size() >= 1);

            // DSP section
            if (fields[0] == "dsp") {
                if (fields.size() != 2) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (!tok.empty()) {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }
                tok.push_back(fields[0]);

                dspTypes.resize(dspTypes.size() + 1);\
                dspTypes.back().name = RTLIL::escape_id(fields[1]);
            }
            else if (fields[0] == "enddsp") {
                if (fields.size() != 1) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() != 1 || tok.back() != "dsp") {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }
                tok.pop_back(); 
            }

            // DSP port section
            else if (fields[0] == "port") {
                if (fields.size() != 2) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() != 1 || tok.back() != "dsp") {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }
                tok.push_back(fields[0]);

                auto& ports = dspTypes.back().ports;
                ports.resize(ports.size() + 1);
                ports.back().name = RTLIL::escape_id(fields[1]);
            }
            else if (fields[0] == "endport") {
                if (fields.size() != 1) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() != 2 || tok.back() != "port") {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }
                tok.pop_back(); 
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
            }
            else if (fields[0] == "endff") {
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
                if (fields.size() != 2) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() == 0 || (tok.back() != "port" && tok.back() != "ff")) {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }

                // Associated clock
                if (tok.back() == "port") {
                    auto& ports = dspTypes.back().ports;
                    ports.back().assoc.clk = RTLIL::escape_id(fields[1]);
                }
                else if (tok.back() == "ff") {
                    flopTypes.back().ports.clk = RTLIL::escape_id(fields[1]);
                }
            }
            else if (fields[0] == "rst") {
                if (fields.size() != 2) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() == 0 || (tok.back() != "port" && tok.back() != "ff")) {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }

                // Associated reset
                if (tok.back() == "port") {
                    auto& ports = dspTypes.back().ports;
                    ports.back().assoc.rst = RTLIL::escape_id(fields[1]);
                }
                else if (tok.back() == "ff") {
                    flopTypes.back().ports.rst = RTLIL::escape_id(fields[1]);
                }
            }
            else if (fields[0] == "ena") {
                if (fields.size() != 2) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() == 0 || (tok.back() != "port" && tok.back() != "ff")) {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }

                // Associated enable
                if (tok.back() == "port") {
                    auto& ports = dspTypes.back().ports;
                    ports.back().assoc.ena = RTLIL::escape_id(fields[1]);
                }
                else if (tok.back() == "ff") {
                    flopTypes.back().ports.ena = RTLIL::escape_id(fields[1]);
                }
            }

            else if (fields[0] == "d") {
                if (fields.size() != 2) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() == 0 || tok.back() != "ff") {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }

                flopTypes.back().ports.d = RTLIL::escape_id(fields[1]);
            }
            else if (fields[0] == "q") {
                if (fields.size() != 2) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() == 0 || tok.back() != "ff") {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }

                flopTypes.back().ports.q = RTLIL::escape_id(fields[1]);
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
                for (const auto& it : vec) {
                    set.insert(std::make_pair(
                        RTLIL::escape_id(it.first),
                        RTLIL::Const(it.second)
                    ));
                }

                if (tok.back() == "port") {
                    auto& ports = dspTypes.back().ports;
                    ports.back().params.set.swap(set);
                }
                else if (tok.back() == "ff") {
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
                for (const auto& it : vec) {
                    map.insert(std::make_pair(
                        RTLIL::escape_id(it.first),
                        RTLIL::escape_id(it.second)
                    ));
                }

                if (tok.back() == "port") {
                    auto& ports = dspTypes.back().ports;
                    ports.back().params.map.swap(map);
                }
                else if (tok.back() == "ff") {
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
                auto& ports = dspTypes.back().ports;
                for (const auto& it : vec) {
                    ports.back().connect.insert(std::make_pair(
                        RTLIL::escape_id(it.first),
                        RTLIL::Const(it.second)
                    ));
                }
            }

            else {
                log(" unexpected keyword '%s'\n", fields[0].c_str());
            }
        }

        // Convert lists to maps
        for (const auto& it : dspTypes) {
            m_DspTypes.insert(std::make_pair(it.name, it));
        }
        for (const auto& it : flopTypes) {
            m_FlopTypes.insert(std::make_pair(it.name, it));
        }
    } 

    // TODO: make lambda
    std::vector<std::string> get_fields(const std::string& a_String,
                                        const char a_Delim = ' ',
                                        bool a_KeepEmpty = false)
    {
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
    }

    void dump_rules() {

        // Dump DSP types
        log("DSP types:\n");
        for (const auto& it : m_DspTypes) {
            const auto& dsp = it.second;
            log(" %s\n", dsp.name.c_str());

            log(" ports:\n");
            for (const auto& port : dsp.ports) {
                log("  %s.%s\n", dsp.name.c_str(), port.name.c_str());
                log("   clk: %s\n", !port.assoc.clk.empty() ? port.assoc.clk.c_str() : "<none>");
                log("   rst: %s\n", !port.assoc.rst.empty() ? port.assoc.rst.c_str() : "<none>");
                log("   ena: %s\n", !port.assoc.ena.empty() ? port.assoc.ena.c_str() : "<none>");

                if (!port.params.set.empty()) {
                    log("   set params:\n");
                    for (const auto& it : port.params.set) {
                        log("    %s=%s\n", it.first.c_str(), it.second.decode_string().c_str());
                    }
                }
                if (!port.params.map.empty()) {
                    log("   map params:\n");
                    for (const auto& it : port.params.map) {
                        log("    %s=%s\n", it.first.c_str(), it.second.c_str());
                    }
                }
                if (!port.connect.empty()) {
                    log("   connect ports:\n");
                    for (const auto& it : port.connect) {
                        log("    %s.%s=%s\n", dsp.name.c_str(), it.first.c_str(), it.second.as_string().c_str());
                    }
                }
            }
        }

        // Dump flop types
        log("Flip-flop types:\n");
        for (const auto& it : m_FlopTypes) {
            const auto& ff = it.second;
            log(" %s\n", ff.name.c_str());
            log("  clk: %s\n", !ff.ports.clk.empty() ? ff.ports.clk.c_str() : "<none>");
            log("  rst: %s\n", !ff.ports.rst.empty() ? ff.ports.rst.c_str() : "<none>");
            log("  ena: %s\n", !ff.ports.ena.empty() ? ff.ports.ena.c_str() : "<none>");
            log("  d  : %s\n", !ff.ports.d.empty()   ? ff.ports.d.c_str()   : "<none>");
            log("  q  : %s\n", !ff.ports.q.empty()   ? ff.ports.q.c_str()   : "<none>");

            if (!ff.params.set.empty()) {
                log("  set params:\n");
                for (const auto& it : ff.params.set) {
                    log("   %s=%s\n", it.first.c_str(), it.second.decode_string().c_str());
                }
            }
            if (!ff.params.map.empty()) {
                log("  map params:\n");
                for (const auto& it : ff.params.map) {
                    log("   %s=%s\n", it.first.c_str(), it.second.c_str());
                }
            }
        }
    }

    // ..........................................

    /// Temporary SigBit to SigBit helper map.
    SigMap m_SigMap;
    /// Net map
    dict<RTLIL::SigBit, RTLIL::SigBit> m_NetMap;

    /// DSP types
    dict<RTLIL::IdString, DspType>    m_DspTypes;
    /// Flip-flop types
    dict<RTLIL::IdString, FlopType>   m_FlopTypes;

    // ..........................................

    DspFF() :
        Pass("dsp_ff", "Integrates flip-flop into DSP blocks")
    {}

    void help () override {
        log("\n");
        log("    dsp_ff -rules <rules.txt> [selection]\n");
        log("\n");
        log("Integrates flip-flops with DSP blocks and enables their internal registers.\n");
        log("\n");
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

        // Load rules
        load_rules(rulesFile);
        if (log_force_debug) {
            dump_rules();
        }

        // Process modules
        for (auto module : a_Design->selected_modules()) {

            // Setup the SigMap
            m_SigMap.clear();
            m_SigMap.set(module);

        }

        // Clear maps
        m_SigMap.clear();
    }

/*
    pool<CellPin> getSinks (const CellPin& a_Driver) {

        auto module = a_Driver.cell->module;
        pool<CellPin> sinks;

        // The driver has to be an output pin
        if (!a_Driver.cell->output(a_Driver.port)) {
            return sinks;
        }

        // Get the driver sigbit
        auto driverSigspec = a_Driver.cell->getPort(a_Driver.port);
        auto driverSigbit = m_SigMap(driverSigspec.bits().at(a_Driver.bit));

        // Look for connected sinks
        for (auto cell : module->cells()) {
            for (auto conn : cell->connections()) {
                auto port = conn.first;
                auto sigspec = conn.second;

                // Consider only sinks (inputs)
                if (!cell->input(port)) {
                    continue;
                }

                // Check all sigbits
                auto sigbits = sigspec.bits();
                for (size_t bit = 0; bit < sigbits.size(); ++bit) {

                    auto sigbit = sigbits[bit];
                    if (!sigbit.wire) {
                        continue;
                    }

                    // Got a sink pin of another cell
                    sigbit = m_SigMap(sigbit);
                    if (sigbit == driverSigbit) {
                        sinks.insert(CellPin(cell, port, bit));
                    }
                }
            }
        }

        // Look for connected top-level output ports
        for (auto conn : module->connections()) {
            auto dst = conn.first;
            auto src = conn.second;

            auto sigbits = dst.bits();
            for (size_t bit = 0; bit < sigbits.size(); ++bit) {

                auto sigbit = sigbits[bit];
                if (!sigbit.wire) {
                    continue;
                }

                if (!sigbit.wire->port_output) {
                    continue;
                }

                sigbit = m_SigMap(sigbit);
                if (sigbit == driverSigbit) {
                    sinks.insert(CellPin(nullptr, sigbit.wire->name, bit));
                }
            }
        }

        return sinks;
    }
*/

} DspFF;

PRIVATE_NAMESPACE_END

