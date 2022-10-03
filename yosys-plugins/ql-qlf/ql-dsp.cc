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
 *
 */

#include "kernel/sigtools.h"
#include "kernel/yosys.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

#include "pmgen/ql-dsp-pm.h"

void create_ql_dsp(ql_dsp_pm &pm)
{
    auto &st = pm.st_ql_dsp;

    log("Checking %s.%s for QL DSP inference.\n", log_id(pm.module), log_id(st.mul));

    log_debug("ffA:    %s\n", log_id(st.ffA, "--"));
    log_debug("ffB:    %s\n", log_id(st.ffB, "--"));
    log_debug("ffCD:   %s\n", log_id(st.ffCD, "--"));
    log_debug("mul:    %s\n", log_id(st.mul, "--"));
    log_debug("ffFJKG: %s\n", log_id(st.ffFJKG, "--"));
    log_debug("ffH:    %s\n", log_id(st.ffH, "--"));
    log_debug("add:    %s\n", log_id(st.add, "--"));
    log_debug("mux:    %s\n", log_id(st.mux, "--"));
    log_debug("ffO:    %s\n", log_id(st.ffO, "--"));
    log_debug("\n");

    if (GetSize(st.sigA) > 16) {
        log("  input A (%s) is too large (%d > 16).\n", log_signal(st.sigA), GetSize(st.sigA));
        return;
    }

    if (GetSize(st.sigB) > 16) {
        log("  input B (%s) is too large (%d > 16).\n", log_signal(st.sigB), GetSize(st.sigB));
        return;
    }

    if (GetSize(st.sigO) > 33) {
        log("  adder/accumulator (%s) is too large (%d > 33).\n", log_signal(st.sigO), GetSize(st.sigO));
        return;
    }

    if (GetSize(st.sigH) > 32) {
        log("  output (%s) is too large (%d > 32).\n", log_signal(st.sigH), GetSize(st.sigH));
        return;
    }

    Cell *cell = st.mul;
    if (cell->type == ID($mul)) {
        log("  replacing %s with QL_DSP cell.\n", log_id(st.mul->type));

        cell = pm.module->addCell(NEW_ID, ID(QL_DSP));
        pm.module->swap_names(cell, st.mul);
    } else
        log_assert(cell->type == ID(QL_DSP));

    // QL_DSP Input Interface
    SigSpec A = st.sigA;
    A.extend_u0(16, st.mul->getParam(ID::A_SIGNED).as_bool());
    log_assert(GetSize(A) == 16);

    SigSpec B = st.sigB;
    B.extend_u0(16, st.mul->getParam(ID::B_SIGNED).as_bool());
    log_assert(GetSize(B) == 16);

    SigSpec CD = st.sigCD;
    if (CD.empty())
        CD = RTLIL::Const(0, 32);
    else
        log_assert(GetSize(CD) == 32);

    cell->setPort(ID::A, A);
    cell->setPort(ID::B, B);
    cell->setPort(ID::C, CD.extract(16, 16));
    cell->setPort(ID::D, CD.extract(0, 16));

    cell->setParam(ID(A_REG), st.ffA ? State::S1 : State::S0);
    cell->setParam(ID(B_REG), st.ffB ? State::S1 : State::S0);
    cell->setParam(ID(C_REG), st.ffCD ? State::S1 : State::S0);
    cell->setParam(ID(D_REG), st.ffCD ? State::S1 : State::S0);

    // QL_DSP Output Interface

    SigSpec O = st.sigO;
    int O_width = GetSize(O);
    if (O_width == 33) {
        log_assert(st.add);
        // If we have a signed multiply-add, then perform sign extension
        if (st.add->getParam(ID::A_SIGNED).as_bool() && st.add->getParam(ID::B_SIGNED).as_bool())
            pm.module->connect(O[32], O[31]);
        else
            cell->setPort(ID::CO, O[32]);
        O.remove(O_width - 1);
    } else
        cell->setPort(ID::CO, pm.module->addWire(NEW_ID));
    log_assert(GetSize(O) <= 32);
    if (GetSize(O) < 32)
        O.append(pm.module->addWire(NEW_ID, 32 - GetSize(O)));

    cell->setPort(ID::O, O);

    cell->setParam(ID::A_SIGNED, st.mul->getParam(ID::A_SIGNED).as_bool());
    cell->setParam(ID::B_SIGNED, st.mul->getParam(ID::B_SIGNED).as_bool());

    if (cell != st.mul)
        pm.autoremove(st.mul);
    else
        pm.blacklist(st.mul);
    pm.autoremove(st.ffFJKG);
    pm.autoremove(st.add);
}

struct QlDspPass : public Pass {
    QlDspPass() : Pass("ql_dsp", "ql: map multipliers") {}
    void help() override
    {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("    ql_dsp [options] [selection]\n");
        log("\n");
        log("Map multipliers ($mul/QL_DSP) and multiply-accumulate ($mul/QL_DSP + $add)\n");
        log("cells into ql DSP resources.\n");
        log("Pack input registers (A, B, {C,D}), pipeline registers\n");
        log("({F,J,K,G}, H), output registers (O -- full 32-bits or lower 16-bits only); \n");
        log("and post-adder into into the QL_DSP resource.\n");
        log("\n");
        log("Multiply-accumulate operations using the post-adder with feedback on the {C,D}\n");
        log("input will be folded into the DSP. In this scenario only, resetting the\n");
        log("the accumulator to an arbitrary value can be inferred to use the {C,D} input.\n");
        log("\n");
    }
    void execute(std::vector<std::string> args, RTLIL::Design *design) override
    {
        log_header(design, "Executing ql_DSP pass (map multipliers).\n");

        size_t argidx;
        for (argidx = 1; argidx < args.size(); argidx++) {
            break;
        }
        extra_args(args, argidx, design);

        for (auto module : design->selected_modules())
            ql_dsp_pm(module, module->selected_cells()).run_ql_dsp(create_ql_dsp);
    }
} QlDspPass;

PRIVATE_NAMESPACE_END
