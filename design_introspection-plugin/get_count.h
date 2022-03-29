/*
 * Copyright (C) 2019-2022 The SymbiFlow Authors
 *
 * Use of this source code is governed by a ISC-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/ISC
 *
 * SPDX-License-Identifier: ISC
 *
 */
#ifndef _GET_COUNT_H_
#define _GET_COUNT_H_

#include "kernel/register.h"

USING_YOSYS_NAMESPACE

struct GetCount : public Pass {

    enum class ObjectType { NONE, MODULE, CELL, WIRE };

    GetCount() : Pass("get_count", "Returns count of various selected object types to the TCL interpreter") {}

    void help() override;
    void execute(std::vector<std::string> a_Args, RTLIL::Design *a_Design) override;
};

#endif // GET_COUNT_H_
