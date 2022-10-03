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
#include "clocks.h"
#include "kernel/register.h"
#include "propagation.h"
#include <cassert>
#include <cmath>
#include <regex>

void Clock::Add(const std::string &name, RTLIL::Wire *wire, float period, float rising_edge, float falling_edge, ClockType type)
{
    wire->set_string_attribute(RTLIL::escape_id("CLOCK_SIGNAL"), "yes");
    wire->set_bool_attribute(RTLIL::escape_id("IS_GENERATED"), type == GENERATED);
    wire->set_bool_attribute(RTLIL::escape_id("IS_EXPLICIT"), type == EXPLICIT);
    wire->set_bool_attribute(RTLIL::escape_id("IS_PROPAGATED"), type == PROPAGATED);
    wire->set_string_attribute(RTLIL::escape_id("CLASS"), "clock");
    wire->set_string_attribute(RTLIL::escape_id("NAME"), name);
    wire->set_string_attribute(RTLIL::escape_id("SOURCE_WIRES"), Clock::WireName(wire));
    wire->set_string_attribute(RTLIL::escape_id("PERIOD"), std::to_string(period));
    std::string waveform(std::to_string(rising_edge) + " " + std::to_string(falling_edge));
    wire->set_string_attribute(RTLIL::escape_id("WAVEFORM"), waveform);
}

void Clock::Add(const std::string &name, std::vector<RTLIL::Wire *> wires, float period, float rising_edge, float falling_edge, ClockType type)
{
    std::for_each(wires.begin(), wires.end(), [&](RTLIL::Wire *wire) { Add(name, wire, period, rising_edge, falling_edge, type); });
}

void Clock::Add(RTLIL::Wire *wire, float period, float rising_edge, float falling_edge, ClockType type)
{
    Add(Clock::WireName(wire), wire, period, rising_edge, falling_edge, type);
}

float Clock::Period(RTLIL::Wire *clock_wire)
{
    if (!clock_wire->has_attribute(RTLIL::escape_id("PERIOD"))) {
        log_cmd_error("PERIOD has not been specified on wire '%s'.\n", WireName(clock_wire).c_str());
    }
    float period(0);
    std::string period_str;
    try {
        period_str = clock_wire->get_string_attribute(RTLIL::escape_id("PERIOD"));
        period = std::stof(period_str);
    } catch (const std::invalid_argument &e) {
        log_cmd_error("Incorrect value '%s' specifed on PERIOD attribute for wire "
                      "'%s'.\nPERIOD needs to be a float value.\n",
                      period_str.c_str(), WireName(clock_wire).c_str());
    }
    return period;
}

std::pair<float, float> Clock::Waveform(RTLIL::Wire *clock_wire)
{
    if (!clock_wire->has_attribute(RTLIL::escape_id("WAVEFORM"))) {
        float period(Period(clock_wire));
        if (!period) {
            log_cmd_error("Neither PERIOD nor WAVEFORM has been specified for wire %s\n", WireName(clock_wire).c_str());
            return std::make_pair(0, 0);
        }
        float falling_edge = period / 2;
        log_warning("Waveform has not been specified on wire '%s'.\nDefault value {0 %f} "
                    "will be used\n",
                    WireName(clock_wire).c_str(), falling_edge);
        return std::make_pair(0, falling_edge);
    }
    float rising_edge(0);
    float falling_edge(0);
    std::string waveform(clock_wire->get_string_attribute(RTLIL::escape_id("WAVEFORM")));
    if (std::sscanf(waveform.c_str(), "%f %f", &rising_edge, &falling_edge) != 2) {
        log_cmd_error("Incorrect value '%s' specifed on WAVEFORM attribute for wire "
                      "'%s'.\nWAVEFORM needs to be specified in form of '<rising_edge> "
                      "<falling_edge>' where the edge values are floats.\n",
                      waveform.c_str(), WireName(clock_wire).c_str());
    }
    return std::make_pair(rising_edge, falling_edge);
}

float Clock::RisingEdge(RTLIL::Wire *clock_wire) { return Waveform(clock_wire).first; }

float Clock::FallingEdge(RTLIL::Wire *clock_wire) { return Waveform(clock_wire).second; }

std::string Clock::Name(RTLIL::Wire *clock_wire)
{
    if (clock_wire->has_attribute(RTLIL::escape_id("NAME"))) {
        return clock_wire->get_string_attribute(RTLIL::escape_id("NAME"));
    }
    return WireName(clock_wire);
}

std::string Clock::WireName(RTLIL::Wire *clock_wire)
{
    if (!clock_wire) {
        return std::string();
    }
    return AddEscaping(RTLIL::unescape_id(clock_wire->name));
}

std::string Clock::SourceWireName(RTLIL::Wire *clock_wire)
{
    if (clock_wire->has_attribute(RTLIL::escape_id("SOURCE_WIRES"))) {
        return clock_wire->get_string_attribute(RTLIL::escape_id("SOURCE_WIRES"));
    }
    return Name(clock_wire);
}

bool Clock::GetClockWireBoolAttribute(RTLIL::Wire *wire, const std::string &attribute_name)
{
    if (wire->has_attribute(RTLIL::escape_id(attribute_name))) {
        return wire->get_bool_attribute(RTLIL::escape_id(attribute_name));
    }
    return false;
}

const std::map<std::string, RTLIL::Wire *> Clocks::GetClocks(RTLIL::Design *design)
{
    std::map<std::string, RTLIL::Wire *> clock_wires;
    RTLIL::Module *top_module = design->top_module();
    for (auto &wire_obj : top_module->wires_) {
        auto &wire = wire_obj.second;
        if (wire->has_attribute(RTLIL::escape_id("CLOCK_SIGNAL"))) {
            if (wire->get_string_attribute(RTLIL::escape_id("CLOCK_SIGNAL")) == "yes") {
                clock_wires.insert(std::make_pair(Clock::WireName(wire), wire));
            }
        }
    }
    return clock_wires;
}

void Clocks::UpdateAbc9DelayTarget(RTLIL::Design *design)
{
    std::map<std::string, RTLIL::Wire *> clock_wires = Clocks::GetClocks(design);

    for (auto &clock_wire : clock_wires) {
        auto &wire = clock_wire.second;
        float period = Clock::Period(wire);

        // Set the ABC9 delay to the shortest clock period in the design.
        //
        // By convention, delays in Yosys are in picoseconds, but ABC9 has
        // no information on interconnect delay, so target half the specified
        // clock period to give timing slack; otherwise ABC9 may produce a
        // mapping that cannot meet the specified clock.
        int abc9_delay = design->scratchpad_get_int("abc9.D", INT32_MAX);
        int period_ps = period * 1000.0 / 2.0;
        design->scratchpad_set_int("abc9.D", std::min(abc9_delay, period_ps));
    }
}
