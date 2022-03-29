/*
 * Copyright (C) 2019-2022 The SymbiFlow Authors
 *
 * Use of this source code is governed by a ISC-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/ISC
 *
 * SPDX-License-Identifier: ISC
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
