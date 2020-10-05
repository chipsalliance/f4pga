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
#ifndef _SET_CLOCK_GROUPS_H_
#define _SET_CLOCK_GROUPS_H_

#include "kernel/register.h"
#include "kernel/rtlil.h"
#include "sdc_writer.h"

USING_YOSYS_NAMESPACE

struct SetClockGroups : public Pass {
    SetClockGroups(SdcWriter& sdc_writer)
        : Pass("set_clock_groups", "Set exclusive or asynchronous clock groups"),
          sdc_writer_(sdc_writer) {}

    void help() override;

    void execute(std::vector<std::string> args, RTLIL::Design* design) override;

    SdcWriter& sdc_writer_;
};

#endif  //_SET_CLOCK_GROUPS_H_
