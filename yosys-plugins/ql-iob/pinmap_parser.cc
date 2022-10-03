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
#include "pinmap_parser.hh"

#include <sstream>

// ============================================================================

bool PinmapParser::parse(const std::string &a_FileName)
{

    // Open the file
    std::ifstream file(a_FileName.c_str());

    // Parse it
    return parse(file);
}

const std::vector<PinmapParser::Entry> PinmapParser::getEntries() const { return m_Entries; }

// ============================================================================

std::vector<std::string> PinmapParser::getFields(const std::string &a_String)
{

    std::vector<std::string> fields;
    std::stringstream ss(a_String);

    while (ss.good()) {
        std::string field;
        std::getline(ss, field, ',');

        fields.push_back(field);
    }

    return fields;
}

bool PinmapParser::parseHeader(std::ifstream &a_Stream)
{

    // Get the header line
    std::string header;
    std::getline(a_Stream, header);

    // Parse fields
    m_Fields = getFields(header);
    if (m_Fields.empty()) {
        return false;
    }

    return true;
}

bool PinmapParser::parseData(std::ifstream &a_Stream)
{

    // Parse lines as they come
    while (a_Stream.good()) {
        std::string line;
        std::getline(a_Stream, line);

        if (line.empty()) {
            continue;
        }

        // Parse datafields
        auto data = getFields(line);

        // Assign data fields to columns
        Entry entry;
        for (size_t i = 0; i < data.size(); ++i) {

            if (i >= m_Fields.size()) {
                return false;
            }

            entry[m_Fields[i]] = data[i];
        }

        m_Entries.push_back(entry);
    }

    return true;
}

bool PinmapParser::parse(std::ifstream &a_Stream)
{

    if (!a_Stream.good()) {
        return false;
    }

    // Clear pinmap entries
    m_Entries.clear();

    // Parse header
    if (!parseHeader(a_Stream)) {
        return false;
    }
    // Parse data fields
    if (!parseData(a_Stream)) {
        return false;
    }

    return true;
}
