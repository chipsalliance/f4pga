#include "kernel/sigtools.h"
#include "kernel/yosys.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

#include "pmgen/ql-dsp-macc.h"

// ============================================================================

void create_ql_macc_dsp (ql_dsp_macc_pm& pm) {
    auto& st = pm.st_ql_dsp_macc;

    log("pattern:\n");
    log("mul: %s (%s)\n",
        RTLIL::unescape_id(pm.st_ql_dsp_macc.mul->name).c_str(),
        RTLIL::unescape_id(pm.st_ql_dsp_macc.mul->type).c_str()
    );
    log("add: %s (%s)\n",
        RTLIL::unescape_id(pm.st_ql_dsp_macc.add->name).c_str(),
        RTLIL::unescape_id(pm.st_ql_dsp_macc.add->type).c_str()
    );
    if (st.mux != nullptr) {
        log("mux: %s (%s)\n",
            RTLIL::unescape_id(st.mux->name).c_str(),
            RTLIL::unescape_id(st.mux->type).c_str()
        );
    }
    log("ff : %s (%s)\n",
        RTLIL::unescape_id(pm.st_ql_dsp_macc.ff->name).c_str(),
        RTLIL::unescape_id(pm.st_ql_dsp_macc.ff->type).c_str()
    );

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
