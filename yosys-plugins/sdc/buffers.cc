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
#include "buffers.h"
#include <cassert>
#include <cmath>

const std::vector<std::string> Pll::inputs = {"CLKIN1", "CLKIN2"};
const std::vector<std::string> Pll::outputs = {"CLKOUT0", "CLKOUT1", "CLKOUT2", "CLKOUT3", "CLKOUT4", "CLKOUT5"};
const float Pll::delay = 0;
const std::string Pll::name = "PLLE2_ADV";

Pll::Pll(RTLIL::Cell *cell, float input_clock_period, float input_clock_rising_edge) : ClockDivider({"PLLE2_ADV"})
{
    assert(RTLIL::unescape_id(cell->type) == "PLLE2_ADV");
    FetchParams(cell);
    CheckInputClockPeriod(cell, input_clock_period);
    CalculateOutputClockPeriods();
    CalculateOutputClockWaveforms(input_clock_rising_edge);
}

void Pll::CheckInputClockPeriod(RTLIL::Cell *cell, float input_clock_period)
{
    float abs_diff = fabs(ClkinPeriod() - input_clock_period);
    bool approx_equal = abs_diff < std::max(ClkinPeriod(), input_clock_period) * 10 * std::numeric_limits<float>::epsilon();
    if (!approx_equal) {
        log_cmd_error("CLKIN[1/2]_PERIOD doesn't match the virtual clock constraint "
                      "propagated to the CLKIN[1/2] input of the clock divider cell: "
                      "%s.\nInput clock period: %f, CLKIN[1/2]_PERIOD: %f\n",
                      RTLIL::id2cstr(cell->name), input_clock_period, ClkinPeriod());
    }
}

void Pll::FetchParams(RTLIL::Cell *cell)
{
    clkin1_period = FetchParam(cell, "CLKIN1_PERIOD", 0.0);
    clkin2_period = FetchParam(cell, "CLKIN2_PERIOD", 0.0);
    clk_mult = FetchParam(cell, "CLKFBOUT_MULT", 5.0);
    clk_fbout_phase = FetchParam(cell, "CLKFBOUT_PHASE", 0.0);
    divclk_divisor = FetchParam(cell, "DIVCLK_DIVIDE", 1.0);
    for (auto output : outputs) {
        // CLKOUT[0-5]_DUTY_CYCLE
        clkout_duty_cycle[output] = FetchParam(cell, output + "_DUTY_CYCLE", 0.5);
        // CLKOUT[0-5]_DIVIDE
        clkout_divisor[output] = FetchParam(cell, output + "_DIVIDE", 1.0);
        // CLKOUT[0-5]_PHASE
        clkout_phase[output] = FetchParam(cell, output + "_PHASE", 0.0);
    }
}

void Pll::CalculateOutputClockPeriods()
{
    for (auto output : outputs) {
        // CLKOUT[0-5]_PERIOD = CLKIN1_PERIOD * CLKOUT[0-5]_DIVIDE *
        // DIVCLK_DIVIDE / CLKFBOUT_MULT
        clkout_period[output] = ClkinPeriod() * clkout_divisor.at(output) / clk_mult * divclk_divisor;
    }
}

void Pll::CalculateOutputClockWaveforms(float input_clock_rising_edge)
{
    for (auto output : outputs) {
        float output_clock_period = clkout_period.at(output);
        clkout_rising_edge[output] =
          fmod(input_clock_rising_edge - (clk_fbout_phase / 360.0) * ClkinPeriod() + output_clock_period * (clkout_phase[output] / 360.0),
               output_clock_period);
        clkout_falling_edge[output] = fmod(clkout_rising_edge[output] + clkout_duty_cycle[output] * output_clock_period, output_clock_period);
    }
}

float Pll::FetchParam(RTLIL::Cell *cell, std::string &&param_name, float default_value)
{
    RTLIL::IdString param(RTLIL::escape_id(param_name));
    if (cell->hasParam(param)) {
        auto param_obj = cell->parameters.at(param);
        std::string value;
        if (param_obj.flags & RTLIL::CONST_FLAG_STRING) {
            value = param_obj.decode_string();
        } else {
            value = std::to_string(param_obj.as_int());
        }
        return std::stof(value);
    }
    return default_value;
}
