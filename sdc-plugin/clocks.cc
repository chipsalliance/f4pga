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
#include "clocks.h"
#include <algorithm>
#include "kernel/log.h"
#include "kernel/register.h"

void Clocks::AddClock(const std::string& name,
              const std::vector<RTLIL::Wire*>& clock_wires, float period,
              float rising_edge, float falling_edge) {
    std::for_each(clock_wires.begin(), clock_wires.end(), [&, this](RTLIL::Wire* wire) {
	AddClockWire(name, wire, period, rising_edge, falling_edge);
    });
}

void Clocks::AddClockWire(const std::string& name, RTLIL::Wire* wire,
                          float period) {
    // Set default duty cycle 50%
    AddClockWire(name, wire, period, 0, period / 2);
}

void Clocks::AddClockWire(const std::string& name, RTLIL::Wire* wire,
                          float period, float rising_edge, float falling_edge) {
    auto clock = clocks_.find(name);
    if (clock == clocks_.end()) {
	clocks_.emplace(std::make_pair(
	    name, Clock(name, wire, period, rising_edge, falling_edge)));
    } else {
	clock->second.AddClockWire(wire, period, rising_edge, falling_edge);
    }
}

std::vector<std::string> Clocks::GetClockNames() {
    std::vector<std::string> res;
    for (auto clock : clocks_) {
	res.push_back(clock.first);
    }
    return res;
}


Clock::Clock(const std::string& name, RTLIL::Wire* wire, float period,
             float rising_edge, float falling_edge)
    : Clock(name) {
    AddClockWire(wire, period, rising_edge, falling_edge);
}

void Clock::AddClockWire(RTLIL::Wire* wire, float period, float rising_edge,
                         float falling_edge) {
    clock_wires_.emplace_back(wire, period, rising_edge, falling_edge);
}
