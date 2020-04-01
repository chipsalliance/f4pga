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
#ifndef PINMAP_PARSER_HH
#define PINMAP_PARSER_HH

#include <istream>
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
    bool parse (std::istream*& a_Stream);

    /// Returns a vector of entries
    const std::vector<Entry> getEntries() const;

protected:

    /// Splits the input string into a vector of fields. Fields are comma
    /// separated.
    static std::vector<std::string> getFields (const std::string& a_String);

    /// Parses the header
    bool parseHeader (std::istream*& a_Stream);
    /// Parses the data
    bool parseData   (std::istream*& a_Stream);

    /// Header fields
    std::vector<std::string> m_Fields;
    /// A list of entries
    std::vector<Entry> m_Entries;
};

#endif // PINMAP_PARSER_HH
