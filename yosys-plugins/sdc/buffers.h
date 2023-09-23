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
#ifndef _BUFFERS_H_
#define _BUFFERS_H_

#include "kernel/rtlil.h"
#include <string>
#include <unordered_map>
#include <vector>

USING_YOSYS_NAMESPACE

struct Buffer {
    Buffer(float delay, const std::string &type, const std::string &output) : delay(delay), type(type), output(output) {}
    float delay;
    std::string type;
    std::string output;
};

struct IBuf : Buffer {
    IBuf() : Buffer(0, "IBUF", "O"){};
};

struct Bufg : Buffer {
    Bufg() : Buffer(0, "BUFG", "O"){};
};

struct ClockDivider {
    std::string type;
};

struct Pll : public ClockDivider {
    Pll() : ClockDivider({"PLLE2_ADV"}) {}
    Pll(RTLIL::Cell *cell, float input_clock_period, float input_clock_rising_edge);

    // Helper function to fetch a cell parameter or return a default value
    static float FetchParam(RTLIL::Cell *cell, std::string &&param_name, float default_value);

    // Get the period of the input clock
    // TODO Add support for CLKINSEL
    float ClkinPeriod() { return clkin1_period; }

    static const std::vector<std::string> inputs;
    static const std::vector<std::string> outputs;
    std::unordered_map<std::string, float> clkout_period;
    std::unordered_map<std::string, float> clkout_duty_cycle;
    std::unordered_map<std::string, float> clkout_rising_edge;
    std::unordered_map<std::string, float> clkout_falling_edge;

  private:
    // Approximate equality check of the input clock period and specified in
    // CLKIN[1/2]_PERIOD parameter
    void CheckInputClockPeriod(RTLIL::Cell *cell, float input_clock_period);

    // Fetch cell's parameters needed for further calculations
    void FetchParams(RTLIL::Cell *cell);

    // Calculate the period on the output clocks
    void CalculateOutputClockPeriods();

    // Calculate the rising and falling edges of the output clocks
    void CalculateOutputClockWaveforms(float input_clock_rising_edge);

    static const float delay;
    static const std::string name;
    std::unordered_map<std::string, float> clkout_divisor;
    std::unordered_map<std::string, float> clkout_phase;
    float clkin1_period;
    float clkin2_period;
    float divclk_divisor;
    float clk_mult;
    float clk_fbout_phase;
};

#endif // _BUFFERS_H_
