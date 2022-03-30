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
