/*
 * Copyright (C) 2019-2022 The SymbiFlow Authors
 *
 * Use of this source code is governed by a ISC-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/ISC
 *
 * SPDX-License-Identifier: ISC
 *
 */
#include "pcf_parser.hh"

#include <regex>

// ============================================================================

bool PcfParser::parse(const std::string &a_FileName)
{

    // Open the file
    std::ifstream file(a_FileName.c_str());

    // Parse it
    return parse(file);
}

const std::vector<PcfParser::Constraint> PcfParser::getConstraints() const { return m_Constraints; }

// ============================================================================

bool PcfParser::parse(std::ifstream &a_Stream)
{

    if (!a_Stream.good()) {
        return false;
    }

    // Clear constraints
    m_Constraints.clear();

    // Parse PCF lines
    std::regex re("^\\s*set_io\\s+([^#\\s]+)\\s+([^#\\s]+)(?:\\s+#(.*))?");

    while (a_Stream.good()) {
        std::string line;
        std::getline(a_Stream, line);

        // Match against regex
        std::cmatch cm;
        if (std::regex_match(line.c_str(), cm, re)) {
            m_Constraints.push_back(Constraint(cm[1].str(), cm[2].str(), cm[3].str()));
        }
    }

    return true;
}
