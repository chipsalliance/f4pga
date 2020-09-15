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
#ifndef _BUFFERS_H_
#define _BUFFERS_H_

#include <cassert>
#include <initializer_list>
#include <string>
#include <unordered_map>
#include <vector>
#include "kernel/rtlil.h"

USING_YOSYS_NAMESPACE

struct Buffer {
    Buffer(float delay, const std::string& name, const std::string& output)
        : delay(delay), name(name), output(output) {}
    float delay;
    std::string name;
    std::string output;
};

struct IBuf : Buffer {
    IBuf() : Buffer(0, "IBUF", "O"){};
};

struct Bufg : Buffer {
    Bufg() : Buffer(1, "BUFG", "O"){};
};

struct Pll {
    Pll(RTLIL::Cell* cell) : cell(cell) {
	assert(RTLIL::unescape_id(cell->type) == "PLLE2_ADV");
	clkin1_period = FetchParam(cell, "CLKIN1_PERIOD", 0.0);
	clkin2_period = FetchParam(cell, "CLKIN2_PERIOD", 0.0);
	clk_mult = FetchParam(cell, "CLKFBOUT_MULT", 5.0);
	divclk_divisor = FetchParam(cell, "DIVCLK_DIVIDE", 1.0);
	for (auto clk_output : outputs) {
	    // CLKOUT[0-5]_DIVIDE
	    clkout_divisors[clk_output] = FetchParam(cell, clk_output + "_DIVIDE", 1.0);
	    clkout_period[clk_output] = CalculatePeriod(clk_output);

	    // CLKOUT[0-5]_PHASE
	    clkout_phase[clk_output] = FetchParam(cell, clk_output + "_PHASE", 0.0);

	    // Take the delay off the PLL into account
	    clkout_shift[clk_output] = CalculateShift(clk_output) + delay;

	    // CLKOUT[0-5]_DUTY_CYCLE
	    clkout_duty_cycle[clk_output] = FetchParam(cell, clk_output + "_DUTY_CYCLE", 0.5);
	}
    };

    // CLKOUT[0-5]_PERIOD = CLKIN1_PERIOD * CLKOUT[0-5]_DIVIDE * DIVCLK_DIVIDE /
    // CLKFBOUT_MULT
    // TODO Check the value on CLKINSEL
    float CalculatePeriod(const std::string& output) {
	return clkin1_period * clkout_divisors.at(output) / clk_mult *
	       divclk_divisor;
    }

    float CalculateShift(const std::string& output) {
	return clkout_period.at(output) * clkout_phase.at(output) / 360.0;
    }

    float FetchParam(RTLIL::Cell* cell, std::string&& param_name, float default_value) {
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

    static const float delay;
    static const std::string name;
    static const std::vector<std::string> inputs;
    static const std::vector<std::string> outputs;
    RTLIL::Cell* cell;
    std::unordered_map<std::string, float> clkout_period;
    std::unordered_map<std::string, float> clkout_duty_cycle;
    std::unordered_map<std::string, float> clkout_phase;
    std::unordered_map<std::string, float> clkout_shift;
    std::unordered_map<std::string, float> clkout_divisors;
    float clkin1_period;
    float clkin2_period;
    float divclk_divisor;
    float clk_mult;
};

#endif  // _BUFFERS_H_
