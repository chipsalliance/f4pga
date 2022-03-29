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
