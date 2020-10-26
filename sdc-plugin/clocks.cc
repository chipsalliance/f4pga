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
#include "kernel/register.h"
#include "propagation.h"

void Clock::Add(const std::string& name, RTLIL::Wire* wire, float period,
                float rising_edge, float falling_edge) {
    wire->set_string_attribute(RTLIL::escape_id("CLOCK_SIGNAL"), "yes");
    wire->set_string_attribute(RTLIL::escape_id("CLASS"), "clock");
    wire->set_string_attribute(RTLIL::escape_id("NAME"), name);
    wire->set_string_attribute(RTLIL::escape_id("SOURCE_PINS"),
                               Clock::WireName(wire));
    wire->set_string_attribute(RTLIL::escape_id("PERIOD"),
                               std::to_string(period));
    std::string waveform(std::to_string(rising_edge) + " " +
                         std::to_string(falling_edge));
    wire->set_string_attribute(RTLIL::escape_id("WAVEFORM"), waveform);
}

void Clock::Add(const std::string& name, std::vector<RTLIL::Wire*> wires,
                float period, float rising_edge, float falling_edge) {
    std::for_each(wires.begin(), wires.end(), [&](RTLIL::Wire* wire) {
	Add(name, wire, period, rising_edge, falling_edge);
    });
}

void Clock::Add(RTLIL::Wire* wire, float period, float rising_edge,
                float falling_edge) {
    Add(Clock::WireName(wire), wire, period, rising_edge, falling_edge);
}

float Clock::Period(RTLIL::Wire* clock_wire) {
    if (!clock_wire->has_attribute(RTLIL::escape_id("PERIOD"))) {
	log_warning(
	    "Period has not been specified\n Default value 0 will be used\n");
	return 0;
    }
    return std::stof(
        clock_wire->get_string_attribute(RTLIL::escape_id("PERIOD")));
}

std::pair<float, float> Clock::Waveform(RTLIL::Wire* clock_wire) {
    if (!clock_wire->has_attribute(RTLIL::escape_id("WAVEFORM"))) {
	float period(Period(clock_wire));
	if (!period) {
	    log_cmd_error(
	        "Neither PERIOD nor WAVEFORM has been specified for wire %s\n",
	        WireName(clock_wire).c_str());
	    return std::make_pair(0, 0);
	}
	float falling_edge = period / 2;
	log_warning(
	    "Waveform has not been specified\n Default value {0 %f} will be "
	    "used\n",
	    falling_edge);
	return std::make_pair(0, falling_edge);
    }
    float rising_edge(0);
    float falling_edge(0);
    std::string waveform(
        clock_wire->get_string_attribute(RTLIL::escape_id("WAVEFORM")));
    std::sscanf(waveform.c_str(), "%f %f", &rising_edge, &falling_edge);
    return std::make_pair(rising_edge, falling_edge);
}

float Clock::RisingEdge(RTLIL::Wire* clock_wire) {
    return Waveform(clock_wire).first;
}

float Clock::FallingEdge(RTLIL::Wire* clock_wire) {
    return Waveform(clock_wire).second;
}

std::string Clock::Name(RTLIL::Wire* clock_wire) {
    if (clock_wire->has_attribute(RTLIL::escape_id("NAME"))) {
	return clock_wire->get_string_attribute(RTLIL::escape_id("NAME"));
    }
    return WireName(clock_wire);
}

std::string Clock::WireName(RTLIL::Wire* wire) {
    if (!wire) {
	return std::string();
    }
    std::string wire_name(RTLIL::unescape_id(wire->name));
    return std::regex_replace(wire_name, std::regex{"\\$"}, "\\$");
}

const std::map<std::string, RTLIL::Wire*> Clocks::GetClocks(RTLIL::Design* design) {
    std::map<std::string, RTLIL::Wire*> clock_wires;
    RTLIL::Module* top_module = design->top_module();
    for (auto& wire_obj : top_module->wires_) {
	auto& wire = wire_obj.second;
	if (wire->has_attribute(RTLIL::escape_id("CLOCK_SIGNAL"))) {
	    if (wire->get_string_attribute(RTLIL::escape_id("CLOCK_SIGNAL")) ==
	        "yes") {
		clock_wires.insert(std::make_pair(Clock::WireName(wire), wire));
	    }
	}
    }
    return clock_wires;
}

