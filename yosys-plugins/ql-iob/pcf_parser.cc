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
