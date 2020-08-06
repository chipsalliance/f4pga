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

#include <initializer_list>
#include <string>
#include <unordered_map>
#include <vector>
#include <cassert>
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
    IBuf() : Buffer(1, "IBUF", "O"){};
};

struct Bufg : Buffer {
    Bufg() : Buffer(1, "BUFG", "O"){};
};

struct Pll {
    Pll(float delay, const std::string& name,
        const std::initializer_list<std::string>& outputs)
        : delay(delay), name(name), outputs(outputs.begin(), outputs.end()) {}
    Pll(RTLIL::Cell* cell)
        : Pll(1, "PLLE2_ADV",
              {"CLKOUT0", "CLKOUT1", "CLKOUT2", "CLKOUT3", "CLKOUT4",
               "CLKOUT5"})
          {
	assert(RTLIL::unescape_id(cell->type) == "PLLE2_ADV");
	if (cell->hasParam(ID(CLKIN1_PERIOD))) {
	    clkin1_period =
	        std::stof(cell->getParam(ID(CLKIN1_PERIOD)).decode_string());
	}
	if (cell->hasParam(ID(CLKIN2_PERIOD))) {
	    clkin2_period =
	        std::stof(cell->getParam(ID(CLKIN2_PERIOD)).decode_string());
	}
    };

    float delay;
    std::string name;
    std::vector<std::string> outputs;
    RTLIL::Cell* cell;
    float clkin1_period;
    float clkin2_period;
};

#endif  // _BUFFERS_H_
