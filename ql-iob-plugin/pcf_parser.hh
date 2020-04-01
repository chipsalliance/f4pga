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
#ifndef PCF_PARSER_HH
#define PCF_PARSER_HH

#include <istream>
#include <string>
#include <vector>

// ============================================================================

class PcfParser {
public:

    /// A constraint
    struct Constraint {

        const std::string netName;
        const std::string padName;
        const std::string comment;

        Constraint () = default;

        Constraint (
            const std::string& a_NetName,
            const std::string& a_PadName,
            const std::string& a_Comment = std::string()
        ) : netName(a_NetName), padName(a_PadName), comment(a_Comment) {}
    };

    /// Constructor
    PcfParser () = default;

    /// Parses a PCF file and stores constraint within the class instance.
    /// Returns false in case of error
    bool parse (const std::string& a_FileName);
    bool parse (std::istream*& a_Stream);

    /// Returns the constraint list
    const std::vector<Constraint> getConstraints () const;

protected:

    /// A list of constraints
    std::vector<Constraint> m_Constraints;
};

#endif // PCF_PARSER_HH
