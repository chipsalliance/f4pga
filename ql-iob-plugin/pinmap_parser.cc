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
