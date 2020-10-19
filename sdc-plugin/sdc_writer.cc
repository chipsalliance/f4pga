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
#include "sdc_writer.h"

USING_YOSYS_NAMESPACE

const std::map<ClockGroups::ClockGroupRelation, std::string> ClockGroups::relation_name_map = {
    {NONE, ""},
    {ASYNCHRONOUS, "asynchronous"},
    {PHYSICALLY_EXCLUSIVE, "physically_exclusive"},
    {LOGICALLY_EXCLUSIVE, "logically_exclusive"}};

void SdcWriter::AddFalsePath(FalsePath false_path) {
    false_paths_.push_back(false_path);
}

void SdcWriter::SetMaxDelay(TimingPath timing_path) {
    timing_paths_.push_back(timing_path);
}

void SdcWriter::AddClockGroup(ClockGroups::ClockGroup clock_group, ClockGroups::ClockGroupRelation relation) {
    clock_groups_.Add(clock_group, relation);
}

void SdcWriter::WriteSdc(Clocks& clocks, std::ostream& file) {
    WriteClocks(clocks, file);
    WriteFalsePaths(file);
    WriteMaxDelay(file);
    WriteClockGroups(file);
}

void SdcWriter::WriteClocks(Clocks& clocks, std::ostream& file) {
    for (auto clock : clocks.GetClocks()) {
	auto clock_wires = clock.GetClockWires();
	// FIXME: Input port nets are not found in VPR
	if (std::all_of(clock_wires.begin(), clock_wires.end(),
	                [&](RTLIL::Wire* wire) { return wire->port_input; })) {
	    continue;
	}
	file << "create_clock -period " << clock.Period();
	file << " -waveform {" << clock.RisingEdge() << " "
	     << clock.FallingEdge() << "}";
	for (auto clock_wire : clock_wires) {
	    if (clock_wire->port_input) {
		continue;
	    }
	    file << " " << Clock::ClockWireName(clock_wire);
	}
	file << std::endl;
    }
}

void SdcWriter::WriteFalsePaths(std::ostream& file) {
    for (auto path : false_paths_) {
	file << "set_false_path";
	if (!path.from_pin.empty()) {
	    file << " -from " << path.from_pin;
	}
	if (!path.through_pin.empty()) {
	    file << " -through " << path.through_pin;
	}
	if (!path.to_pin.empty()) {
	    file << " -to " << path.to_pin;
	}
	file << std::endl;
    }
}

void SdcWriter::WriteMaxDelay(std::ostream& file) {
    for (auto path : timing_paths_) {
	file << "set_max_delay " << path.max_delay;
	if (!path.from_pin.empty()) {
	    file << " -from " << path.from_pin;
	}
	if (!path.to_pin.empty()) {
	    file << " -to " << path.to_pin;
	}
	file << std::endl;
    }
}

void SdcWriter::WriteClockGroups(std::ostream& file) {
    for (size_t relation = 0; relation <= ClockGroups::CLOCK_GROUP_RELATION_SIZE; relation++) {
	auto clock_groups = clock_groups_.GetGroups(static_cast<ClockGroups::ClockGroupRelation>(relation));
	if (clock_groups.size() == 0) {
	    continue;
	}
	file << "create_clock_groups ";
	for (auto group : clock_groups) {
	    file << "-group ";
	    for (auto signal : group) {
		file << signal << " ";
	    }
	}
	if (relation != ClockGroups::ClockGroupRelation::NONE) {
	    file << "-" + ClockGroups::relation_name_map.at(static_cast<ClockGroups::ClockGroupRelation>(relation));
	}
	file << std::endl;
    }
}
