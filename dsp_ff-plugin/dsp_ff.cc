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
    struct DspPortType {
        RTLIL::IdString name;

        /// A dict of associated cell ports indexed by their function (like "clk, "rst")
        /// along with the default value to connect when unused.
        dict<RTLIL::IdString, std::pair<RTLIL::IdString, RTLIL::State>> assoc;

        struct {
            /// A dict of parameters to be set in the cell after integration
            dict<RTLIL::IdString, RTLIL::Const>    set;
            /// A dict of parameters to be mapped to the cell after integration
            dict<RTLIL::IdString, RTLIL::IdString> map;
        } params;

        /// A list of ports to be connected to specific constants after flip-flop
        /// integration.
        dict<RTLIL::IdString, RTLIL::Const> connect;
    };

    struct DspType {
        RTLIL::IdString name;
        std::vector<DspPortType> ports;
    };

    // ..........................................

    struct FlopData {
        RTLIL::IdString type;
        dict<RTLIL::IdString, RTLIL::SigBit> conns;
        struct {
            dict<RTLIL::IdString, RTLIL::Const> flop;
            dict<RTLIL::IdString, RTLIL::Const> dsp;
        } params;

        FlopData (const RTLIL::IdString& _type) : type(_type) {};

        FlopData (const FlopData& ref) = default;
        FlopData (FlopData&& ref) = default;

        unsigned int hash () const {
            unsigned int h = 0;
            h = mkhash_add(h, type.hash());
            h = mkhash_add(h, conns.hash());
            h = mkhash_add(h, params.flop.hash());
            h = mkhash_add(h, params.dsp.hash());
            return h;
        }

        bool operator == (const FlopData& ref) const {
            return  (type == ref.type) &&
                    (conns == ref.conns) &&
                    (params.flop == ref.params.flop) &&
                    (params.dsp == ref.params.dsp);
        }
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
                ports.back().assoc.insert(std::make_pair(RTLIL::escape_id("clk"), std::make_pair(RTLIL::IdString(), RTLIL::Sx)));
                ports.back().assoc.insert(std::make_pair(RTLIL::escape_id("rst"), std::make_pair(RTLIL::IdString(), RTLIL::Sx)));
                ports.back().assoc.insert(std::make_pair(RTLIL::escape_id("ena"), std::make_pair(RTLIL::IdString(), RTLIL::Sx)));
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
                flopTypes.back().ports.insert(std::make_pair(RTLIL::escape_id("clk"), RTLIL::IdString()));
                flopTypes.back().ports.insert(std::make_pair(RTLIL::escape_id("rst"), RTLIL::IdString()));
                flopTypes.back().ports.insert(std::make_pair(RTLIL::escape_id("ena"), RTLIL::IdString()));
                flopTypes.back().ports.insert(std::make_pair(RTLIL::escape_id("d"),   RTLIL::IdString()));
                flopTypes.back().ports.insert(std::make_pair(RTLIL::escape_id("q"),   RTLIL::IdString()));
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
                    ports.back().assoc[RTLIL::escape_id("clk")] = std::make_pair(RTLIL::escape_id(fields[1]), RTLIL::S0);
                }
                else if (tok.back() == "ff") {
                    flopTypes.back().ports[RTLIL::escape_id("clk")] = RTLIL::escape_id(fields[1]);
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
                    ports.back().assoc[RTLIL::escape_id("rst")] = std::make_pair(RTLIL::escape_id(fields[1]), RTLIL::S0);
                }
                else if (tok.back() == "ff") {
                    flopTypes.back().ports[RTLIL::escape_id("rst")] = RTLIL::escape_id(fields[1]);
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
                    ports.back().assoc[RTLIL::escape_id("ena")] = std::make_pair(RTLIL::escape_id(fields[1]), RTLIL::S0);
                }
                else if (tok.back() == "ff") {
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
            }
            else if (fields[0] == "q") {
                if (fields.size() != 2) {
                    log_error(" syntax error: '%s'\n", line.c_str());
                }
                if (tok.size() == 0 || tok.back() != "ff") {
                    log_error(" unexpected keyword '%s'\n", fields[0].c_str());
                }

                flopTypes.back().ports[RTLIL::escape_id("q")] = RTLIL::escape_id(fields[1]);
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
                for (const auto& it : port.assoc) {
                    log("   %.3s: %s\n", it.first.c_str(), !it.second.first.empty() ? it.second.first.c_str() : "<none>");
                }

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
            
            for (const auto& it : ff.ports) {
                log("  %.3s: %s\n", it.first.c_str(), !it.second.empty() ? it.second.c_str() : "<none>");
            }

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
//    /// Net map
//    dict<RTLIL::SigBit, RTLIL::SigBit> m_NetMap;
    /// Cells to be removed (per module!)
    pool<RTLIL::Cell*> m_CellsToRemove;

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

    void execute (std::vector<std::string> a_Args, RTLIL::Design *a_Design) override
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

//            // Build the net map
//            buildNetMap(module);

            // Look for DSP cells
            for (auto cell : module->cells()) {

                // Not a DSP
                if (!m_DspTypes.count(cell->type)) {
                    continue;
                }

                // Check ports
                auto& rule = m_DspTypes.at(cell->type);
                for (auto& portRule : rule.ports) {

                    // Sanity check
                    if (!cell->hasPort(portRule.name)) {
                        log(" The DSP cell '%s' does not have a port named '%s'!\n",
                            cell->type.c_str(), portRule.name.c_str());
                        continue;
                    }

                    if (cell->input(portRule.name)) {
                        processInputPort(cell, portRule);
                    }
                    else if (cell->output(portRule.name)) {
                        processOutputPort(cell, portRule);
                    }
                    else {
                        log(" The port '%s.%s' is neither input nor output!\n",
                            cell->type.c_str(), portRule.name.c_str());
                        continue;
                    }
                }
            }

            // Remove cells
            for (const auto& cell : m_CellsToRemove) {
                module->remove(cell);
            }
            m_CellsToRemove.clear();
        }

        // Clear maps
        m_SigMap.clear();
    }

    // ..........................................

//    void buildNetMap (RTLIL::Module* a_Module) {
//        // TODO:
//    }

    bool checkDspPort (RTLIL::Cell* a_Cell, const DspPortType& a_PortRule) {
        bool isOk = true;

        // The cell parameters must not be set
        for (const auto& it : a_PortRule.params.set) {
            const auto curr = a_Cell->getParam(it.first);
            if (curr == it.second) {
                log_debug("  the param '%s' is already set to '%s'\n",
                    it.first.c_str(), it.second.decode_string().c_str());
                isOk = false;
            }
        }

        return isOk;
    }

    bool checkFlop (RTLIL::Cell* a_Cell) {
        const auto& flopType = m_FlopTypes.at(a_Cell->type);
        bool isOk = true;

        log_debug("  Checking connected flip-flop '%s' of type '%s'... ",
            a_Cell->name.c_str(), a_Cell->type.c_str());

        // Check if required parameters are set as they should be
        for (const auto& it : flopType.params.required) {
            const auto curr = a_Cell->getParam(it.first);
            if (curr != it.second) {
                log_debug("\n   param '%s' mismatch ('%s' instead of '%s')",
                    it.first.c_str(), curr.decode_string().c_str(), it.second.decode_string().c_str());
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

/*    
    bool checkFlopDataAgainstDspPort (const FlopData& a_FlopData,
                                      RTLIL::Cell* a_Cell,
                                      const DspPortType& a_PortRule)
    {
        const auto& flopType = m_FlopTypes.at(a_FlopData.type);
        bool isOk = true;

        log_debug("  Checking connected flip-flop settings against the DSP port... ");

        // Check control signal connections
        for (const auto& it : a_PortRule.assoc) {
            const auto& key  = it.first;
            const auto& port = it.second;

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

        // Check parameters to be set (by the port rule)
        for (const auto& it : a_PortRule.params.set) {
            if (a_Cell->hasParam(it.first)) {
                const auto curr = a_Cell->getParam(it.first);
                if (curr != it.second) {
                    log_debug("\n   the param '%s' mismatch ('%s' instead of '%s')",
                        it.first.c_str(), curr.decode_string().c_str(),
                        it.second.decode_string().c_str());
                    isOk = false;
                }
            }
        }

        // Check parameters to be mapped (by the port rule)
        for (const auto& it : a_PortRule.params.map) {
            if (a_Cell->hasParam(it.first) && a_FlopData.params.count(it.second)) {
                const auto curr = a_Cell->getParam(it.first);
                const auto flop = a_FlopData.params.at(it.second);
                if (curr != flop) {
                    log_debug("\n   the param '%s' mismatch ('%s' instead of '%s')",
                        it.first.c_str(), curr.decode_string().c_str(),
                        flop.decode_string().c_str());
                    isOk = false;
                }
            }
        }
        
//        // Check parameters to be set (by the flip-flop type)
//        for (const auto& it : flopType.params.set) {
//            const auto curr = a_Cell->getParam(it.first);
//            if (curr == it.second) {
//                log_debug("\n   the param '%s' is already set to '%s'",
//                    it.first.c_str(), it.second.decode_string().c_str());
//                isOk = false;
//            }
//        }
        
        if (isOk) {
            log_debug("Ok\n");
        } else {
            log_debug("\n");
        }
        return isOk;
    }
*/

    static std::string sigBitName (const RTLIL::SigBit& a_SigBit) {
        if (a_SigBit.is_wire()) {
            RTLIL::Wire* w = a_SigBit.wire;
            return RTLIL::unescape_id(w->name);
        } else {
            switch (a_SigBit.data)
            {
            case RTLIL::State::S0: return "1'b0";
            case RTLIL::State::S1: return "1'b1";
            case RTLIL::State::Sx: return "1'bx";
            case RTLIL::State::Sz: return "1'bz";
            case RTLIL::State::Sa: return "-";
            case RTLIL::State::Sm: return "m";
            }
            return "?";
        }
    }

    // ..........................................

    void processInputPort (RTLIL::Cell* a_Cell, const DspPortType& a_PortRule) {

        log_debug(" Attempting flip-flop integration for %s.%s of %s\n",
            a_Cell->type.c_str(), a_PortRule.name.c_str(), a_Cell->name.c_str());

        // TODO
        log_debug("  TODO: An input port\n");
    }

    void processOutputPort (RTLIL::Cell* a_Cell, const DspPortType& a_PortRule) {

        log_debug(" Attempting flip-flop integration for %s.%s of %s\n",
            a_Cell->type.c_str(), a_PortRule.name.c_str(), a_Cell->name.c_str());

        // Check if the port can be used for FF integration
        if (!checkDspPort(a_Cell, a_PortRule)) {
            log_debug("  port check failed\n");
            return;
        }

        // Get port connections
        auto sigspec = a_Cell->getPort(a_PortRule.name);
        auto sigbits = sigspec.bits();

        // Collect flip-flops, identify their group count
        dict<FlopData, int> groups;

        std::vector<std::pair<RTLIL::Cell*, int>> flops
            (sigbits.size(), std::make_pair(nullptr, -1));

        for (size_t i=0; i<sigbits.size(); ++i) {
            auto sigbit = sigbits[i];
            if (!sigbit.wire) {
                continue;
            }

            // Get sinks(s), discard the port completely if more than one sink
            // is found.
            auto sinks = getSinks(CellPin(a_Cell, a_PortRule.name, i));
            if (sinks.size() > 1) {
                log_debug("  multiple sinks found, cannot integrate.\n");
                return;
            }

            // No sinks - output unconnected
            if (sinks.empty()) {
                continue;
            }

            // Get the sink, check if this is a flip-flop
            auto& sink = *sinks.begin();
            auto* flop = sink.cell;
            if (flop == nullptr || !m_FlopTypes.count(flop->type)) {
                continue;
            }

            // Must not have the "keep" attribute
            if (flop->has_keep_attr()) {
                continue;
            }

            // Check if the connection goes to the data input port
            const auto& flopType = m_FlopTypes.at(flop->type);
            if (flopType.ports.at(RTLIL::escape_id("d")) != sink.port) {
                continue;
            }

            // Skip if the flip-flop is going to be removed
            if (m_CellsToRemove.count(flop)) {
                continue;
            }

            // Check the flip-flop
            if (!checkFlop(flop)) {
                continue;
            }

            // Get parameters to be mapped to the DSP according to the port
            // rule.
            dict<RTLIL::IdString, RTLIL::Const> mappedParams;
            for (const auto& it : a_PortRule.params.map) {
                if (flop->hasParam(it.second)) {
                    const auto& value = flop->getParam(it.second);
                    mappedParams.insert(std::make_pair(it.first, value));
                }
            }

            // Store the flop and its data
            auto res = groups.insert(
                std::make_pair(getFlopData(flop, mappedParams),groups.size())
            );
            flops[i] = std::make_pair(flop, res.first->second);
        }

        // No matching flip-flop groups
        if (groups.empty()) {
            log_debug("  no matching flip-flops found\n");
            return;
        }

        // Do not allow more than a single group
        if (groups.size() != 1) {
            log_debug("  %zu flip-flop groups, only a single one allowed\n", groups.size());
            return;
        }

        // Validate the flip flop data agains the DSP cell
        const auto& flopData = groups.begin()->first;
        const auto& flopType = m_FlopTypes.at(flopData.type);
//        if (!checkFlopDataAgainstDspPort(flopData, a_Cell, a_PortRule)) {
//            log_debug("  flip-flop vs. DSP check failed\n");
//            return;
//        }

        // Debug log
        log(" %s %s.%s\n", a_Cell->type.c_str(), a_Cell->name.c_str(), a_PortRule.name.c_str());
        for (size_t i=0; i<flops.size(); ++i) {
            if (flops[i].first != nullptr) {
                log_debug("  %2zu. (%d) %s %s\n", i,
                    flops[i].second,
                    flops[i].first->type.c_str(), flops[i].first->name.c_str());
            }
            else {
                log_debug("  %2zu. None\n", i);
            }
        }

        // Reconnect data signals, mark the flip-flop for removal
        for (size_t i=0; i<flops.size(); ++i) {

            auto* flop = flops[i].first;
            if (flop == nullptr) {
                continue;
            }

            const auto& port = flopType.ports.at(RTLIL::escape_id("q"));
            if (!flop->hasPort(port)) {
                log_error("  cell '%s' does not have port '%s'!\n",
                    flop->type.c_str(), port.c_str());
            }

            sigbits[i] = SigBit(RTLIL::Sx);
            auto sigspec = flop->getPort(port);
            log_assert(sigspec.bits().size() <= 1);
            if (sigspec.bits().size() == 1) {
                sigbits[i] = sigspec.bits()[0];
            }

            m_CellsToRemove.insert(flop);
        }
        a_Cell->setPort(a_PortRule.name, RTLIL::SigSpec(sigbits));

        // Reconnect (map) control signals. Connect the default value if
        // a particular signal is not present in the flip-flop.
        for (const auto& it : a_PortRule.assoc) {
            const auto& key  = it.first;
            const auto& port = it.second.first;
 
            auto conn = RTLIL::SigBit(it.second.second);
            if (flopData.conns.count(key)) {
                conn = flopData.conns.at(key);
            }

            log_debug("  connecting %s.%s to %s\n", a_Cell->type.c_str(),
                port.c_str(), sigBitName(conn).c_str());
            a_Cell->setPort(port, conn);
        }

        // Connect control signals according to DSP port rule
        for (const auto& it : a_PortRule.connect) {
            log_debug("  connecting %s.%s to %s\n", a_Cell->type.c_str(),
                it.first.c_str(), it.second.as_string().c_str());
            a_Cell->setPort(it.first, it.second);
        }

        // Map parameters (port rule)
        for (const auto& it : a_PortRule.params.map) {            
            if (flopData.params.dsp.count(it.second)) {
                const auto& param = flopData.params.dsp.at(it.second);
                log_debug("  setting param '%s' to '%s'\n", it.first.c_str(), param.decode_string().c_str());
                a_Cell->setParam(it.first, param);
            }
        }

        // Map parameters (flip-flop rule)
        for (const auto& it : flopType.params.map) {            
            if (flopData.params.dsp.count(it.second)) {
                const auto& param = flopData.params.dsp.at(it.second);
                log_debug("  setting param '%s' to '%s'\n", it.first.c_str(), param.decode_string().c_str());
                a_Cell->setParam(it.first, param);
            }
        }

        // Set parameters (port rule)
        for (const auto& it : a_PortRule.params.set) {
            log_debug("  setting param '%s' to '%s'\n", it.first.c_str(), it.second.decode_string().c_str());
            a_Cell->setParam(it.first, it.second);
        }

        // Set parameters (flip-flop rule)
        for (const auto& it : flopType.params.set) {
            log_debug("  setting param '%s' to '%s'\n", it.first.c_str(), it.second.decode_string().c_str());
            a_Cell->setParam(it.first, it.second);
        }
    }

    // ..........................................

    /// Collects flip-flop connectivity data and parameters which defines the
    /// group it belongs to.
    FlopData getFlopData (RTLIL::Cell* a_Cell,
                          const dict<RTLIL::IdString, RTLIL::Const>& a_ExtraParams)
    {
        FlopData data (a_Cell->type);

        log_assert(m_FlopTypes.count(a_Cell->type) != 0);
        const auto& flopType = m_FlopTypes.at(a_Cell->type);

        // Gather connections to control ports
        for (const auto& it : flopType.ports) {

            // Skip "D" and "Q" as they connection will always differ.
            if (it.first == RTLIL::escape_id("d") ||
                it.first == RTLIL::escape_id("q"))
            {
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
        for (const auto& it : flopType.params.matching) {
            log_assert(a_Cell->hasParam(it));
            data.params.flop.insert(std::make_pair(it, a_Cell->getParam(it)));
        }

        // Gather flip-flop parameters to be mapped to the DSP as well
        for (const auto& it : flopType.params.map) {
            log_assert(a_Cell->hasParam(it.second));
            data.params.flop.insert(std::make_pair(it.second, a_Cell->getParam(it.second)));
        }

        // Gather DSP parameters and their values to be set to too
        for (const auto& it : flopType.params.set) {
            data.params.dsp.insert(it);
        }

        // Append extra DSP parameters
        for (const auto& it : a_ExtraParams) {
            data.params.dsp.insert(it);
        }

        return data;
    }

    /// Retrieves a list of sinks driven by the given cell pin.
    /// TODO: This is slow, need to make a lookup for that.
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

} DspFF;

PRIVATE_NAMESPACE_END

