/*
 *  yosys -- Yosys Open SYnthesis Suite
 *
 *  Copyright (C) 2012  Clifford Wolf <clifford@clifford.at>
 *  Copyright (C) 2020  The Symbiflow Authors
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */
#include "pcf_parser.hh"

#include <fstream>
#include <regex>

// ============================================================================

bool PcfParser::parse (const std::string& a_FileName) {

    // Open the file
    std::fstream file(a_FileName.c_str(), std::ifstream::in);

    // Parse it
    std::istream* stream = &file;
    return parse(stream);
}

const std::vector<PcfParser::Constraint> PcfParser::getConstraints () const {
    return m_Constraints;
}


// ============================================================================

bool PcfParser::parse (std::istream*& a_Stream) {

    if (a_Stream == nullptr) {
        return false;
    }

    // Clear constraints
    m_Constraints.clear();

    // Parse PCF lines
    std::regex re("^\\s*set_io\\s+([^#\\s]+)\\s+([^#\\s]+)(?:\\s+#(.*))?");

    while (a_Stream->good()) {
        std::string line;
        std::getline(*a_Stream, line);

        // Match against regex
        std::cmatch cm;
        if (std::regex_match(line.c_str(), cm, re)) {
            m_Constraints.push_back(
                Constraint(
                    cm[1].str(),
                    cm[2].str(),
                    cm[3].str()
                )
            );
        }
    }

    return true;
}
