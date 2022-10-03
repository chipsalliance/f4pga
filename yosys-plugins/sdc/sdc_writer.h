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
 */
#ifndef _SDC_WRITER_H_
#define _SDC_WRITER_H_
#include "clocks.h"
#include <map>

USING_YOSYS_NAMESPACE

struct FalsePath {
    std::string from_pin;
    std::string to_pin;
    std::string through_pin;
};

struct TimingPath {
    std::string from_pin;
    std::string to_pin;
    float max_delay;
};

struct ClockGroups {
    enum ClockGroupRelation { NONE, ASYNCHRONOUS, PHYSICALLY_EXCLUSIVE, LOGICALLY_EXCLUSIVE, CLOCK_GROUP_RELATION_SIZE };
    using ClockGroup = std::vector<std::string>;
    static const std::map<ClockGroupRelation, std::string> relation_name_map;

    void Add(ClockGroup &group, ClockGroupRelation relation) { groups_[relation].push_back(group); }
    std::vector<ClockGroup> GetGroups(ClockGroupRelation relation)
    {
        if (groups_.count(relation)) {
            return groups_.at(relation);
        }
        return std::vector<ClockGroup>();
    }
    size_t size() { return groups_.size(); }

  private:
    std::map<ClockGroupRelation, std::vector<ClockGroup>> groups_;
};

class SdcWriter
{
  public:
    void AddFalsePath(FalsePath false_path);
    void SetMaxDelay(TimingPath timing_path);
    void AddClockGroup(ClockGroups::ClockGroup clock_group, ClockGroups::ClockGroupRelation relation);
    void WriteSdc(RTLIL::Design *design, std::ostream &file, bool include_propagated);

  private:
    void WriteClocks(RTLIL::Design *design, std::ostream &file, bool include_propagated);
    void WriteFalsePaths(std::ostream &file);
    void WriteMaxDelay(std::ostream &file);
    void WriteClockGroups(std::ostream &file);

    std::vector<FalsePath> false_paths_;
    std::vector<TimingPath> timing_paths_;
    ClockGroups clock_groups_;
};

#endif // _SDC_WRITER_H_
