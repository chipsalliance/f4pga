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
#ifndef _CLOCKS_H_
#define _CLOCKS_H_

#include "buffers.h"
#include "kernel/rtlil.h"
#include <map>
#include <vector>

USING_YOSYS_NAMESPACE

class NaturalPropagation;
class BufferPropagation;
class ClockDividerPropagation;
class Propagation;

class Clock
{
  public:
    // We distinguish the following types of clock:
    // * EXPLICIT - added with create_clocks command
    // * GENERATED - propagated from explicit clocks changing the clock's parameters
    // * PROPAGATED - propagated from explicit clocks but with the same parameters as the driver
    enum ClockType { EXPLICIT, GENERATED, PROPAGATED };
    static void Add(const std::string &name, RTLIL::Wire *wire, float period, float rising_edge, float falling_edge, ClockType type);
    static void Add(const std::string &name, std::vector<RTLIL::Wire *> wires, float period, float rising_edge, float falling_edge, ClockType type);
    static void Add(RTLIL::Wire *wire, float period, float rising_edge, float falling_edge, ClockType type);
    static float Period(RTLIL::Wire *clock_wire);
    static float RisingEdge(RTLIL::Wire *clock_wire);
    static float FallingEdge(RTLIL::Wire *clock_wire);
    static std::string Name(RTLIL::Wire *clock_wire);
    static std::string WireName(RTLIL::Wire *wire);
    static std::string AddEscaping(const std::string &name) { return std::regex_replace(name, std::regex{"\\$"}, "\\$"); }
    static std::string SourceWireName(RTLIL::Wire *clock_wire);
    static bool IsPropagated(RTLIL::Wire *wire) { return GetClockWireBoolAttribute(wire, "IS_PROPAGATED"); }

    static bool IsGenerated(RTLIL::Wire *wire) { return GetClockWireBoolAttribute(wire, "IS_GENERATED"); }

    static bool IsExplicit(RTLIL::Wire *wire) { return GetClockWireBoolAttribute(wire, "IS_EXPLICIT"); }

  private:
    static std::pair<float, float> Waveform(RTLIL::Wire *clock_wire);

    static bool GetClockWireBoolAttribute(RTLIL::Wire *wire, const std::string &attribute_name);
};

class Clocks
{
  public:
    static const std::map<std::string, RTLIL::Wire *> GetClocks(RTLIL::Design *design);
    static void UpdateAbc9DelayTarget(RTLIL::Design *design);
};

#endif // _CLOCKS_H_
