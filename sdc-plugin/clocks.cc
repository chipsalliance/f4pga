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
#include <cassert>
#include <cmath>
#include <regex>
#include "kernel/log.h"
#include "kernel/register.h"
#include "propagation.h"

void Clocks::AddClock(const std::string& name, std::vector<RTLIL::Wire*> wires,
                      float period, float rising_edge, float falling_edge) {
    std::for_each(wires.begin(), wires.end(), [&, this](RTLIL::Wire* wire) {
	AddClock(name, wire, period, rising_edge, falling_edge);
    });
}

void Clocks::AddClock(const std::string& name, RTLIL::Wire* wire, float period,
                      float rising_edge, float falling_edge) {
    wire->set_string_attribute(RTLIL::escape_id("CLOCK_SIGNAL"), "yes");
    wire->set_string_attribute(RTLIL::escape_id("PERIOD"), std::to_string(period));
}

void Clocks::AddClock(Clock& clock) {
    AddClock(clock.Name(), clock.GetClockWires(), clock.Period(),
             clock.RisingEdge(), clock.FallingEdge());
}

const std::vector<RTLIL::Wire*> Clocks::GetClocks(RTLIL::Design* design) {
    std::vector<RTLIL::Wire*> clock_wires;
    RTLIL::Module* top_module = design->top_module();
    for (auto& wire_obj : top_module->wires_) {
	auto& wire = wire_obj.second;
	if (wire->has_attribute(RTLIL::escape_id("CLOCK_SIGNAL"))) {
		if (wire->get_string_attribute(RTLIL::escape_id("CLOCK_SIGNAL")) == "yes") {
			clock_wires.push_back(wire);
		}
	}
    }
    return clock_wires;
}

std::vector<std::string> Clocks::GetClockNames() {
    std::vector<std::string> res;
    for (auto clock : clocks_) {
	res.push_back(clock.Name());
#ifdef SDC_DEBUG
	std::stringstream ss;
	for (auto clock_wire : clock.GetClockWires()) {
	    ss << RTLIL::unescape_id(clock_wire->name) << " ";
	}
	log("create_clock -period %f -name %s -waveform {%f %f} %s\n",
	    clock.Period(), clock.Name().c_str(), clock.RisingEdge(),
	    clock.FallingEdge(), ss.str().c_str());
#endif
    }
    return res;
}

void Clocks::Propagate(RTLIL::Design* design, NaturalPropagation* pass) {
#ifdef SDC_DEBUG
    log("Start natural clock propagation\n");
#endif
    for (auto& clock_wire : Clocks::GetClocks(design)) {
#ifdef SDC_DEBUG
	log("Processing clock %s\n", RTLIL::id2cstr(clock_wire->name));
#endif
	auto aliases = pass->FindAliasWires(clock_wire);
	/* AddClock(clock.Name(), aliases, clock.Period(), */
	/* 	clock.RisingEdge(), clock.FallingEdge()); */
    }
#ifdef SDC_DEBUG
    log("Finish natural clock propagation\n\n");
#endif
}

void Clocks::Propagate(RTLIL::Design* design, BufferPropagation* pass) {
#ifdef SDC_DEBUG
    log("Start buffer clock propagation\n");
    log("IBUF pass\n");
#endif
    for (auto& clock_wire : Clocks::GetClocks(design)) {
#ifdef SDC_DEBUG
	log("Processing clock %s\n", RTLIL::id2cstr(clock_wire->name));
#endif
	auto period = std::stof(clock_wire->get_string_attribute(RTLIL::escape_id("PERIOD")));
	auto clock = Clock(clock_wire, period, 0, period/2);
	PropagateThroughBuffer(pass, design, clock, IBuf());
    }
#ifdef SDC_DEBUG
    log("BUFG pass\n");
#endif
    for (auto& clock_wire : Clocks::GetClocks(design)) {
#ifdef SDC_DEBUG
	log("Processing clock %s\n", RTLIL::id2cstr(clock_wire->name));
#endif
	auto period = std::stof(clock_wire->get_string_attribute(RTLIL::escape_id("PERIOD")));
	auto clock = Clock(clock_wire, period, 0, period/2);
	PropagateThroughBuffer(pass, design, clock, Bufg());
    }
#ifdef SDC_DEBUG
    log("Finish buffer clock propagation\n\n");
#endif
}

void Clocks::Propagate(RTLIL::Design* design, ClockDividerPropagation* pass) {
#ifdef SDC_DEBUG
    log("Start clock divider clock propagation\n");
#endif
    for (auto& clock_wire : Clocks::GetClocks(design)) {
#ifdef SDC_DEBUG
	log("Processing clock %s\n", RTLIL::id2cstr(clock_wire->name));
#endif
	auto period = std::stof(clock_wire->get_string_attribute(RTLIL::escape_id("PERIOD")));
	auto clock = Clock(clock_wire, period, 0, period/2);
	auto pll_clocks =
	    pass->FindSinkClocksForCellType(clock, "PLLE2_ADV");
	for (auto pll_clock : pll_clocks) {
#ifdef SDC_DEBUG
	    log("PLL clock: %s\n", pll_clock.Name().c_str());
#endif
	    AddClock(pll_clock);
	    PropagateThroughBuffer(pass, design, pll_clock, Bufg());
	}
    }
#ifdef SDC_DEBUG
    log("Finish clock divider clock propagation\n\n");
#endif
}

void Clocks::PropagateThroughBuffer(Propagation* pass, RTLIL::Design* design, Clock& clock,
                                    Buffer buffer) {
    for (auto& clock_wire : Clocks::GetClocks(design)) {
#ifdef SDC_DEBUG
	log("Clock wire %s\n", RTLIL::id2cstr(clock_wire->name));
#endif
	auto buf_wires = pass->FindSinkWiresForCellType(clock_wire, buffer.name,
	                                                buffer.output);
	int path_delay(0);
	for (auto wire : buf_wires) {
#ifdef SDC_DEBUG
	    log("%s wire: %s\n", buffer.name.c_str(),
	        RTLIL::id2cstr(wire->name));
#endif
	    path_delay += buffer.delay;
	    AddClock(RTLIL::unescape_id(wire->name), wire, clock.Period(),
	             clock.RisingEdge() + path_delay,
	             clock.FallingEdge() + path_delay);
	}
    }
}

Clock::Clock(const std::string& name, RTLIL::Wire* wire, float period,
             float rising_edge, float falling_edge)
    : name_(name),
      period_(period),
      rising_edge_(rising_edge),
      falling_edge_(falling_edge) {
    UpdateWires(wire);
}

Clock::Clock(const std::string& name, std::vector<RTLIL::Wire*> wires,
             float period, float rising_edge, float falling_edge)
    : name_(name),
      period_(period),
      rising_edge_(rising_edge),
      falling_edge_(falling_edge) {
    std::for_each(wires.begin(), wires.end(),
                  [&, this](RTLIL::Wire* wire) { UpdateWires(wire); });
}

Clock::Clock(RTLIL::Wire* wire, float period,
             float rising_edge, float falling_edge)
    : Clock(RTLIL::id2cstr(wire->name), wire, period, rising_edge, falling_edge) {}

void Clock::UpdateClock(RTLIL::Wire* wire, float period, float rising_edge,
                        float falling_edge) {
    UpdateWires(wire);
    UpdatePeriod(period);
    UpdateWaveform(rising_edge, falling_edge);
}

void Clock::UpdateWires(RTLIL::Wire* wire) {
    if (std::find(clock_wires_.begin(), clock_wires_.end(), wire) ==
        clock_wires_.end()) {
	clock_wires_.push_back(wire);
    }
}

void Clock::UpdatePeriod(float period) {
    period_ = period;
}

void Clock::UpdateWaveform(float rising_edge, float falling_edge) {
    rising_edge_ = fmod(rising_edge, period_);
    falling_edge_ = fmod(falling_edge, period_);
}

std::string Clock::ClockWireName(RTLIL::Wire* wire) {
    if (!wire) {
	return std::string();
    }
    std::string wire_name(RTLIL::unescape_id(wire->name));
    return std::regex_replace(wire_name, std::regex{"\\$"}, "\\$");
}
