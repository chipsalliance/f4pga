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

float Clock::Period(RTLIL::Wire* clock_wire) {
    if (!clock_wire->has_attribute(RTLIL::escape_id("PERIOD"))) {
	log_warning("Period has not been specified\n Default value 0 will be used\n");
	return 0;
    }
    return std::stof(clock_wire->get_string_attribute(RTLIL::escape_id("PERIOD")));
}

std::pair<float, float> Clock::Waveform(RTLIL::Wire* clock_wire) {
    if (!clock_wire->has_attribute(RTLIL::escape_id("WAVEFORM"))) {
	float period(Period(clock_wire));
	if (!period) {
	    log_cmd_error("Neither PERIOD nor WAVEFORM has been specified for wire %s\n", ClockWireName(clock_wire).c_str());
	    return std::make_pair(0,0);
	}
	float falling_edge = period / 2;
	log_warning("Waveform has not been specified\n Default value {0 %f} will be used\n", falling_edge);
	return std::make_pair(0, falling_edge);
    }
    float rising_edge(0);
    float falling_edge(0);
    std::string waveform(clock_wire->get_string_attribute(RTLIL::escape_id("WAVEFORM")));
    std::sscanf(waveform.c_str(), "%f %f", &rising_edge, &falling_edge);
    return std::make_pair(rising_edge, falling_edge);
}

float Clock::RisingEdge(RTLIL::Wire* clock_wire) {
    return Waveform(clock_wire).first;
}

float Clock::FallingEdge(RTLIL::Wire* clock_wire) {
    return Waveform(clock_wire).second;
}

std::string Clock::ClockWireName(RTLIL::Wire* wire) {
    if (!wire) {
	return std::string();
    }
    std::string wire_name(RTLIL::unescape_id(wire->name));
    return std::regex_replace(wire_name, std::regex{"\\$"}, "\\$");
}

void Clocks::AddClock(const std::string& name, std::vector<RTLIL::Wire*> wires,
                      float period, float rising_edge, float falling_edge) {
    std::for_each(wires.begin(), wires.end(), [&](RTLIL::Wire* wire) {
	AddClock(name, wire, period, rising_edge, falling_edge);
    });
}

void Clocks::AddClock(const std::string& name, RTLIL::Wire* wire, float period,
                      float rising_edge, float falling_edge) {
    wire->set_string_attribute(RTLIL::escape_id("CLOCK_SIGNAL"), "yes");
    wire->set_string_attribute(RTLIL::escape_id("CLASS"), "clock");
    wire->set_string_attribute(RTLIL::escape_id("NAME"), name);
    wire->set_string_attribute(RTLIL::escape_id("SOURCE_PINS"), Clock::ClockWireName(wire));
    wire->set_string_attribute(RTLIL::escape_id("PERIOD"), std::to_string(period));
    std::string waveform(std::to_string(rising_edge) + " " + std::to_string(falling_edge));
    wire->set_string_attribute(RTLIL::escape_id("WAVEFORM"), waveform);
}

void Clocks::AddClock(RTLIL::Wire* wire, float period,
                      float rising_edge, float falling_edge) {
    AddClock(Clock::ClockWireName(wire), wire, period, rising_edge, falling_edge);
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

void Clocks::Propagate(RTLIL::Design* design, NaturalPropagation* pass) {
#ifdef SDC_DEBUG
    log("Start natural clock propagation\n");
#endif
    for (auto& clock_wire : Clocks::GetClocks(design)) {
#ifdef SDC_DEBUG
	log("Processing clock %s\n", RTLIL::id2cstr(clock_wire->name));
#endif
	auto aliases = pass->FindAliasWires(clock_wire);
	AddClock(Clock::ClockWireName(clock_wire), aliases,
	         Clock::Period(clock_wire), Clock::RisingEdge(clock_wire),
	         Clock::FallingEdge(clock_wire));
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
    PropagateThroughBuffers(pass, design, IBuf());
#ifdef SDC_DEBUG
    log("BUFG pass\n");
#endif
    PropagateThroughBuffers(pass, design, Bufg());
#ifdef SDC_DEBUG
    log("Finish buffer clock propagation\n\n");
#endif
}

void Clocks::Propagate(RTLIL::Design* design, ClockDividerPropagation* pass) {
#ifdef SDC_DEBUG
    log("Start clock divider clock propagation\n");
#endif
    PropagateThroughClockDividers(pass, design, Pll());
    PropagateThroughBuffers(pass, design, Bufg());
#ifdef SDC_DEBUG
    log("Finish clock divider clock propagation\n\n");
#endif
}

void Clocks::PropagateThroughBuffers(Propagation* pass, RTLIL::Design* design,
                                    Buffer buffer) {
    for (auto& clock_wire : Clocks::GetClocks(design)) {
#ifdef SDC_DEBUG
	log("Clock wire %s\n", Clock::ClockWireName(clock_wire).c_str());
#endif
	auto buf_wires = pass->FindSinkWiresForCellType(clock_wire, buffer.type,
	                                                buffer.output);
	int path_delay(0);
	for (auto wire : buf_wires) {
#ifdef SDC_DEBUG
	    log("%s wire: %s\n", buffer.type.c_str(),
	        RTLIL::id2cstr(wire->name));
#endif
	    path_delay += buffer.delay;
	    AddClock(wire, Clock::Period(clock_wire),
	             Clock::RisingEdge(clock_wire) + path_delay,
	             Clock::FallingEdge(clock_wire) + path_delay);
	}
    }
}

void Clocks::PropagateThroughClockDividers(ClockDividerPropagation* pass, RTLIL::Design* design,
                                    ClockDivider divider) {
    for (auto& clock_wire : Clocks::GetClocks(design)) {
#ifdef SDC_DEBUG
	log("Processing clock %s\n", Clock::ClockWireName(clock_wire).c_str());
#endif
	pass->PropagateClocksForCellType(clock_wire, divider.type);
    }
}
