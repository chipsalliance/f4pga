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
#ifndef _SET_CLOCK_GROUPS_H_
#define _SET_CLOCK_GROUPS_H_

#include "kernel/register.h"
#include "kernel/rtlil.h"
#include "sdc_writer.h"

USING_YOSYS_NAMESPACE

struct SetClockGroups : public Pass {
    SetClockGroups(SdcWriter &sdc_writer) : Pass("set_clock_groups", "Set exclusive or asynchronous clock groups"), sdc_writer_(sdc_writer) {}

    void help() override;

    void execute(std::vector<std::string> args, RTLIL::Design *design) override;

    SdcWriter &sdc_writer_;
};

#endif //_SET_CLOCK_GROUPS_H_
