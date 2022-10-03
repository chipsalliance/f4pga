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
#ifndef PINMAP_PARSER_HH
#define PINMAP_PARSER_HH

#include <fstream>
#include <string>
#include <vector>
#include <map>

// ============================================================================

class PinmapParser {
public:

    /// A pinmap entry type
    typedef std::map<std::string, std::string> Entry;

    /// Constructor
    PinmapParser () = default;

    /// Parses a pinmap CSV file
    bool parse (const std::string& a_FileName);
    bool parse (std::ifstream& a_Stream);

    /// Returns a vector of entries
    const std::vector<Entry> getEntries() const;

private:

    /// Splits the input string into a vector of fields. Fields are comma
    /// separated.
    static std::vector<std::string> getFields (const std::string& a_String);

    /// Parses the header
    bool parseHeader (std::ifstream& a_Stream);
    /// Parses the data
    bool parseData   (std::ifstream& a_Stream);

    /// Header fields
    std::vector<std::string> m_Fields;
    /// A list of entries
    std::vector<Entry> m_Entries;
};

#endif // PINMAP_PARSER_HH
