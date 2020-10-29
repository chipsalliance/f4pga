/*
 *  yosys -- Yosys Open SYnthesis Suite
 *
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

    void Add(ClockGroup& group, ClockGroupRelation relation) {
	groups_[relation].push_back(group);
    }
    std::vector<ClockGroup> GetGroups(ClockGroupRelation relation) {
	if (groups_.count(relation)) {
	    return groups_.at(relation);
	}
	return std::vector<ClockGroup>();
    }
    size_t size() {
	return groups_.size();
    }

   private:
    std::map<ClockGroupRelation,std::vector<ClockGroup>> groups_;
};

class SdcWriter {
   public:
    void AddFalsePath(FalsePath false_path);
    void SetMaxDelay(TimingPath timing_path);
    void AddClockGroup(ClockGroups::ClockGroup clock_group, ClockGroups::ClockGroupRelation relation);
    void WriteSdc(RTLIL::Design* design, std::ostream& file);

   private:
    void WriteClocks(RTLIL::Design* design, std::ostream& file);
    void WriteFalsePaths(std::ostream& file);
    void WriteMaxDelay(std::ostream& file);
    void WriteClockGroups(std::ostream& file);

    std::vector<FalsePath> false_paths_;
    std::vector<TimingPath> timing_paths_;
    ClockGroups clock_groups_;
};

#endif  // _SDC_WRITER_H_
