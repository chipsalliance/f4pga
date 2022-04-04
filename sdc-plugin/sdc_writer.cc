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
#include "sdc_writer.h"

USING_YOSYS_NAMESPACE

const std::map<ClockGroups::ClockGroupRelation, std::string> ClockGroups::relation_name_map = {
  {NONE, ""}, {ASYNCHRONOUS, "asynchronous"}, {PHYSICALLY_EXCLUSIVE, "physically_exclusive"}, {LOGICALLY_EXCLUSIVE, "logically_exclusive"}};

void SdcWriter::AddFalsePath(FalsePath false_path) { false_paths_.push_back(false_path); }

void SdcWriter::SetMaxDelay(TimingPath timing_path) { timing_paths_.push_back(timing_path); }

void SdcWriter::AddClockGroup(ClockGroups::ClockGroup clock_group, ClockGroups::ClockGroupRelation relation)
{
    clock_groups_.Add(clock_group, relation);
}

void SdcWriter::WriteSdc(RTLIL::Design *design, std::ostream &file, bool include_propagated)
{
    WriteClocks(design, file, include_propagated);
    WriteFalsePaths(file);
    WriteMaxDelay(file);
    WriteClockGroups(file);
}

void SdcWriter::WriteClocks(RTLIL::Design *design, std::ostream &file, bool include_propagated)
{
    for (auto &clock : Clocks::GetClocks(design)) {
        auto &clock_wire = clock.second;
        // FIXME: Input port nets are not found in VPR
        if (clock_wire->port_input) {
            continue;
        }
        // Write out only GENERATED and EXPLICIT clocks
        if (Clock::IsPropagated(clock_wire) and !include_propagated) {
            continue;
        }
        file << "create_clock -period " << Clock::Period(clock_wire);
        file << " -waveform {" << Clock::RisingEdge(clock_wire) << " " << Clock::FallingEdge(clock_wire) << "}";
        file << " " << Clock::SourceWireName(clock_wire);
        file << std::endl;
    }
}

void SdcWriter::WriteFalsePaths(std::ostream &file)
{
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

void SdcWriter::WriteMaxDelay(std::ostream &file)
{
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

void SdcWriter::WriteClockGroups(std::ostream &file)
{
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
