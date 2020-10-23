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
#ifndef _CLOCKS_H_
#define _CLOCKS_H_

#include <vector>
#include "buffers.h"
#include "kernel/rtlil.h"

USING_YOSYS_NAMESPACE

class NaturalPropagation;
class BufferPropagation;
class ClockDividerPropagation;
class Propagation;

class Clock {
   public:
    static void Add(const std::string& name, RTLIL::Wire* wire, float period,
                  float rising_edge, float falling_edge);
    static void Add(const std::string& name, std::vector<RTLIL::Wire*> wires,
                  float period, float rising_edge, float falling_edge);
    static void Add(RTLIL::Wire* wire, float period,
                  float rising_edge, float falling_edge);
    static float Period(RTLIL::Wire* clock_wire);
    static float RisingEdge(RTLIL::Wire* clock_wire);
    static float FallingEdge(RTLIL::Wire* clock_wire);
    static std::string ClockWireName(RTLIL::Wire* wire);

   private:
    static std::pair<float, float> Waveform(RTLIL::Wire* clock_wire);
};

class Clocks {
   public:
    static const std::vector<RTLIL::Wire*> GetClocks(RTLIL::Design* design);
};

#endif  // _CLOCKS_H_
