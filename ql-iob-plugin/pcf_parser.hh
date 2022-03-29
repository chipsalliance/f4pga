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
#ifndef PCF_PARSER_HH
#define PCF_PARSER_HH

#include <fstream>
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
    bool parse (std::ifstream& a_Stream);

    /// Returns the constraint list
    const std::vector<Constraint> getConstraints () const;

private:

    /// A list of constraints
    std::vector<Constraint> m_Constraints;
};

#endif // PCF_PARSER_HH
