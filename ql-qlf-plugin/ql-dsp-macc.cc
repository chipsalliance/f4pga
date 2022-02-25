#include "kernel/sigtools.h"
#include "kernel/yosys.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

#include "pmgen/ql-dsp-macc.h"

// ============================================================================

void create_ql_macc_dsp (ql_dsp_macc_pm& pm) {
    auto& st = pm.st_ql_dsp_macc;

    // Get port widths
    size_t a_width = GetSize(st.mul->getPort(ID(A)));
    size_t b_width = GetSize(st.mul->getPort(ID(B)));
    size_t z_width = GetSize(st.ff->getPort(ID(Q)));

    size_t min_width = std::min(a_width, b_width);
    size_t max_width = std::max(a_width, b_width);

    // Signed / unsigned
    bool a_signed = st.mul->getParam(ID(A_SIGNED)).as_bool();
    bool b_signed = st.mul->getParam(ID(B_SIGNED)).as_bool();

    // Determine DSP type or discard if too narrow / wide
    RTLIL::IdString type;
    size_t tgt_a_width;
    size_t tgt_b_width;
    size_t tgt_z_width;

    if (min_width <= 2 && max_width <= 2 && z_width <= 4) {
        // Too narrow
        return;
    }
    else if (min_width <=  9 && max_width <= 10 && z_width <= 19) {
        type = RTLIL::escape_id("dsp_t1_10x9x32");
        tgt_a_width = 10;
        tgt_b_width = 9;
        tgt_z_width = 19;
    }
    else if (min_width <= 18 && max_width <= 20 && z_width <= 38) {
        type = RTLIL::escape_id("dsp_t1_20x18x64");
        tgt_a_width = 20;
        tgt_b_width = 18;
        tgt_z_width = 38;
    }
    else {
        // Too wide
        return;
    }

    log("Inferring MACC %zux%zu->%zu as %s from:\n",
        a_width, b_width, z_width, RTLIL::unescape_id(type).c_str());

    for (auto cell : {st.mul, st.add, st.mux, st.ff}) {
        if (cell != nullptr) {
            log(" %s (%s)\n",
                RTLIL::unescape_id(cell->name).c_str(),
                RTLIL::unescape_id(cell->type).c_str()
            );
        }
    }

    // Build the DSP cell name
    std::string name;
    name += RTLIL::unescape_id(st.mul->name) + "_";
    name += RTLIL::unescape_id(st.add->name) + "_";
    if (st.mux != nullptr) {
        name += RTLIL::unescape_id(st.mux->name) + "_";
    }
    name += RTLIL::unescape_id(st.ff->name);

    // Add the DSP cell
    RTLIL::Cell* cell = pm.module->addCell(RTLIL::escape_id(name), type);

    // Get input/output data signals
    RTLIL::SigSpec sig_a;
    RTLIL::SigSpec sig_b;
    RTLIL::SigSpec sig_z;

    if (a_width >= b_width) {
        sig_a = st.mul->getPort(ID(A));
        sig_b = st.mul->getPort(ID(B));
    } else {
        sig_a = st.mul->getPort(ID(B));
        sig_b = st.mul->getPort(ID(A));
    }
    sig_z = st.ff->getPort(ID(Q));

    // Connect input data ports, sign extend / pad with zeros
    sig_a.extend_u0(tgt_a_width, a_signed);
    sig_b.extend_u0(tgt_b_width, b_signed);
    cell->setPort(RTLIL::escape_id("a_i"), sig_a);
    cell->setPort(RTLIL::escape_id("b_i"), sig_b);

    // Connect output data port, pad if needed
    if ((size_t)GetSize(sig_z) < tgt_z_width) {
        auto* wire = pm.module->addWire(NEW_ID, tgt_z_width - GetSize(sig_z));
        sig_z.append(wire);
    }
    cell->setPort(RTLIL::escape_id("z_o"), sig_z);

    // Connect clock and reset
    cell->setPort(RTLIL::escape_id("clock_i"), st.ff->getPort(ID(CLK)));
    if (st.ff->type == RTLIL::escape_id("$adff")) {
        cell->setPort(RTLIL::escape_id("reset_i"), st.ff->getPort(ID(ARST)));
    } else {
        cell->setPort(RTLIL::escape_id("reset_i"), RTLIL::SigSpec(RTLIL::S0));
    }

    // Insert feedback_i control logic used for clearing / loading the accumulator
    if (st.mux != nullptr) {
        // TODO:
    }
    // No acc clear/load
    else {
        cell->setPort(RTLIL::escape_id("feedback_i"), RTLIL::SigSpec(RTLIL::S0, 3));
    }

    // Connect control ports
    cell->setPort(RTLIL::escape_id("load_acc_i"), RTLIL::SigSpec(RTLIL::S1));
    cell->setPort(RTLIL::escape_id("unsigned_a_i"), RTLIL::SigSpec(a_signed ? RTLIL::S0 : RTLIL::S1));
    cell->setPort(RTLIL::escape_id("unsigned_b_i"), RTLIL::SigSpec(b_signed ? RTLIL::S0 : RTLIL::S1));

    // Connect config ports
    cell->setPort(RTLIL::escape_id("output_select_i"), RTLIL::SigSpec({RTLIL::S0, RTLIL::S1, RTLIL::S0}));
    cell->setPort(RTLIL::escape_id("saturate_enable_i"), RTLIL::SigSpec(RTLIL::S0));
    cell->setPort(RTLIL::escape_id("shift_right_i"), RTLIL::SigSpec(RTLIL::S0, 6));
    cell->setPort(RTLIL::escape_id("round_i"), RTLIL::SigSpec(RTLIL::S0));
    cell->setPort(RTLIL::escape_id("register_inputs_i"), RTLIL::SigSpec(RTLIL::S0));

    bool subtract = (st.add->type == RTLIL::escape_id("$sub"));
    cell->setPort(RTLIL::escape_id("subtract_i"), RTLIL::SigSpec(subtract ? RTLIL::S1 : RTLIL::S0));

    // Mark the cells for removal
    pm.autoremove(st.mul);
    pm.autoremove(st.add);
    if (st.mux != nullptr) {
        pm.autoremove(st.mux);
    }
    pm.autoremove(st.ff);
}

struct QlDspMacc : public Pass {

    QlDspMacc() : Pass("ql_dsp_macc", "Does something") {}

    void help() override {
        log("\n");
        log("    ql_dsp_macc [options] [selection]\n");
        log("\n");
    }

    void execute (std::vector<std::string> a_Args, RTLIL::Design *a_Design) override {
        log_header(a_Design, "Executing QL_DSP_MACC pass.\n");

        size_t argidx;
        for (argidx = 1; argidx < a_Args.size(); argidx++) {
            break;
        }
        extra_args(a_Args, argidx, a_Design);

        for (auto module : a_Design->selected_modules()) {
            ql_dsp_macc_pm(module, module->selected_cells()).run_ql_dsp_macc(create_ql_macc_dsp);
        }
    }
} QlDspMacc;

PRIVATE_NAMESPACE_END
