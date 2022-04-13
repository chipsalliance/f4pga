#include "kernel/sigtools.h"
#include "kernel/yosys.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

#include "pmgen/ql-bram-asymmetric-wider-read.h"
#include "pmgen/ql-bram-asymmetric-wider-write.h"

void test_ql_bram_asymmetric_wider_read(ql_bram_asymmetric_wider_read_pm &pm)
{
    auto mem = pm.st_ql_bram_asymmetric_wider_read.mem;
    auto mem_wr_addr = pm.st_ql_bram_asymmetric_wider_read.mem_wr_addr;
    auto mem_rd_data = pm.st_ql_bram_asymmetric_wider_read.mem_rd_data;
    auto mem_rd_addr = pm.st_ql_bram_asymmetric_wider_read.mem_rd_addr;
    auto mux = pm.st_ql_bram_asymmetric_wider_read.mux;
    auto mux_s = pm.st_ql_bram_asymmetric_wider_read.mux_s;
    auto wr_en_shift = pm.st_ql_bram_asymmetric_wider_read.wr_en_shift;
    auto wr_en_shift_b = pm.st_ql_bram_asymmetric_wider_read.wr_en_shift_b;
    auto wr_data_shift = pm.st_ql_bram_asymmetric_wider_read.wr_data_shift;
    auto wr_data_shift_a = pm.st_ql_bram_asymmetric_wider_read.wr_data_shift_a;
    auto wr_data_shift_b = pm.st_ql_bram_asymmetric_wider_read.wr_data_shift_b;
    auto wr_en_and = pm.st_ql_bram_asymmetric_wider_read.wr_en_and;
    auto wr_en_and_a = pm.st_ql_bram_asymmetric_wider_read.wr_en_and_a;
    auto wr_en_and_b = pm.st_ql_bram_asymmetric_wider_read.wr_en_and_b;
    auto wr_en_and_y = pm.st_ql_bram_asymmetric_wider_read.wr_en_and_y;

    // Add the BRAM cell
    RTLIL::Cell *cell = pm.module->addCell(RTLIL::escape_id("bram_asymmetric"), mem);

    // Set new type for cell so that it won't be processed by memory_bram pass
    cell->type = IdString("$mem_v2_asymmetric");

    // Prepare wires from memory cell side to compare against module wires
    if (!mux_s.as_wire())
        log_error("WR_EN input wire not found");
    RTLIL::Wire *wr_en_cw = mux_s.as_wire();
    if (!mem_wr_addr.as_wire())
        log_error("WR_ADDR input wire not found");
    RTLIL::Wire *wr_addr_cw = mem_wr_addr.as_wire();
    if (!wr_data_shift_a.as_wire())
        log_error("WR_DATA input wire not found");
    RTLIL::Wire *wr_data_cw = wr_data_shift_a.as_wire();
    if (!mem_rd_addr.as_wire())
        log_error("RD_ADDR input wire not found");
    RTLIL::Wire *rd_addr_cw = mem_rd_addr.as_wire();
    if (!mem_rd_data.as_wire())
        log_error("RD_DATA input wire not found");
    RTLIL::Wire *rd_data_cw = mem_rd_data.as_wire();

    // Check if wr_en_and cell has one of its inputs connected to write address
    RTLIL::Wire *wr_en_and_a_w = nullptr;
    RTLIL::Wire *wr_en_and_b_w = nullptr;
    bool has_wire = false;
    if (wr_en_and_a.is_wire()) {
        has_wire = true;
        wr_en_and_a_w = wr_en_and_a.as_wire();
    }
    if (wr_en_and_b.is_wire()) {
        has_wire = true;
        wr_en_and_b_w = wr_en_and_b.as_wire();
    }
    if (!has_wire)
        log_error("RD_ADDR $and cell input wire not found");
    if ((wr_en_and_a_w != mem_wr_addr.as_wire()) & (wr_en_and_b_w != mem_wr_addr.as_wire()))
        log_error("This is not the $and cell we are looking for");

    // Compare and assign wires
    RTLIL::Wire *wr_en_w = nullptr;
    RTLIL::Wire *wr_addr_w = nullptr;
    RTLIL::Wire *wr_data_w = nullptr;
    RTLIL::Wire *rd_addr_w = nullptr;
    RTLIL::Wire *rd_data_w = nullptr;

    for (auto wire : pm.module->wires_) {
        if (wire.second == wr_en_cw)
            wr_en_w = wire.second;
        if (wire.second == wr_addr_cw)
            wr_addr_w = wire.second;
        if (wire.second == wr_data_cw)
            wr_data_w = wire.second;
        if (wire.second == rd_data_cw)
            rd_data_w = wire.second;
        if (wire.second == rd_addr_cw)
            rd_addr_w = wire.second;
    }

    if (!wr_en_w | !wr_addr_w | !wr_data_w | !rd_data_w | !rd_addr_w)
        log_error("Match between RAM input wires and memory cell ports not found\n");

    // Get address and data lines widths
    int rd_addr_width = rd_addr_w->width;
    int wr_addr_width = wr_addr_w->width;
    int wr_data_width = wr_data_w->width;
    int rd_data_width = rd_data_w->width;

    log_debug("Set RD_ADDR_WIDTH = %d, ", rd_addr_width);
    log_debug("WR_ADDR_WIDTH = %d, ", wr_addr_width);
    log_debug("RD_DATA_WIDTH = %d, ", rd_data_width);
    log_debug("WR_DATA_WIDTH = %d\n", wr_data_width);

    // Set address and data lines width parameters used later in techmap
    cell->setParam(RTLIL::escape_id("RD_ADDR_WIDTH"), RTLIL::Const(rd_addr_width));
    cell->setParam(RTLIL::escape_id("RD_DATA_WIDTH"), RTLIL::Const(rd_data_width));
    cell->setParam(RTLIL::escape_id("WR_ADDR_WIDTH"), RTLIL::Const(wr_addr_width));
    cell->setParam(RTLIL::escape_id("WR_DATA_WIDTH"), RTLIL::Const(wr_data_width));

    int offset;

    switch (wr_data_width) {
    case 1:
        offset = 0;
        break;
    case 2:
        offset = 1;
        break;
    case 4:
        offset = 2;
        break;
    case 8:
    case 9:
        offset = 3;
        break;
    case 16:
    case 18:
        offset = 4;
        break;
    case 32:
    case 36:
        offset = 5;
        break;
    default:
        offset = 0;
        break;
    }

    if (wr_en_and_y != wr_en_shift_b.extract(offset, wr_addr_width))
        log_error("This is not the wr_en $shl cell we are looking for");
    if (wr_en_and_y != wr_data_shift_b.extract(offset, wr_addr_width))
        log_error("This is not the wr_data $shl cell we are looking for");

    // Bypass shift on write address line
    cell->setPort(RTLIL::escape_id("WR_ADDR"), RTLIL::SigSpec(wr_addr_w));

    // Bypass shift on write address line
    cell->setPort(RTLIL::escape_id("WR_DATA"), RTLIL::SigSpec(wr_data_w));

    // Bypass shift on write address line
    cell->setPort(RTLIL::escape_id("WR_EN"), RTLIL::SigSpec(wr_en_w));

    // Cleanup the module from unused cells
    pm.module->remove(mem);
    pm.module->remove(mux);
    pm.module->remove(wr_en_shift);
    pm.module->remove(wr_en_and);
    pm.module->remove(wr_data_shift);
}

void test_ql_bram_asymmetric_wider_write(ql_bram_asymmetric_wider_write_pm &pm)
{
    auto mem = pm.st_ql_bram_asymmetric_wider_write.mem;
    auto mem_wr_addr = pm.st_ql_bram_asymmetric_wider_write.mem_wr_addr;
    auto mem_wr_data = pm.st_ql_bram_asymmetric_wider_write.mem_wr_data;
    auto mem_rd_data = pm.st_ql_bram_asymmetric_wider_write.mem_rd_data;
    auto mem_rd_addr = pm.st_ql_bram_asymmetric_wider_write.mem_rd_addr;
    auto rd_data_shift = pm.st_ql_bram_asymmetric_wider_write.rd_data_shift;
    auto rd_data_shift_y = pm.st_ql_bram_asymmetric_wider_write.rd_data_shift_y;
    auto rd_data_ff = pm.st_ql_bram_asymmetric_wider_write.rd_data_ff;
    auto rd_data_ff_q = pm.st_ql_bram_asymmetric_wider_write.rd_data_ff_q;
    auto rd_data_ff_en = pm.st_ql_bram_asymmetric_wider_write.rd_data_ff_en;
    auto rd_data_ff_clk = pm.st_ql_bram_asymmetric_wider_write.rd_data_ff_clk;
    auto wr_addr_ff = pm.st_ql_bram_asymmetric_wider_write.wr_addr_ff;
    auto wr_addr_ff_d = pm.st_ql_bram_asymmetric_wider_write.wr_addr_ff_d;
    auto wr_en_mux = pm.st_ql_bram_asymmetric_wider_write.wr_en_mux;
    auto wr_en_mux_s = pm.st_ql_bram_asymmetric_wider_write.wr_en_mux_s;
    auto rd_addr_and = pm.st_ql_bram_asymmetric_wider_write.rd_addr_and;
    auto rd_addr_and_a = pm.st_ql_bram_asymmetric_wider_write.rd_addr_and_a;
    auto rd_addr_and_b = pm.st_ql_bram_asymmetric_wider_write.rd_addr_and_b;

    // Add the BRAM cell
    RTLIL::Cell *cell = pm.module->addCell(RTLIL::escape_id("bram_asymmetric"), mem);

    // Set new type for cell so that it won't be processed by memory_bram pass
    cell->type = IdString("$mem_v2_asymmetric");

    // Prepare wires from memory cell side to compare against module wires
    RTLIL::Wire *rd_data_wc = nullptr;
    RTLIL::Wire *rd_en_wc = nullptr;
    RTLIL::Wire *clk_wc = nullptr;
    RTLIL::Wire *rd_addr_and_a_wc = nullptr;
    RTLIL::Wire *rd_addr_and_b_wc = nullptr;

    if (rd_data_ff) {
        if (!rd_data_ff_q.as_wire())
            log_error("RD_DATA input wire not found");
        rd_data_wc = rd_data_ff_q.as_wire();
        if (!rd_data_ff_en.as_wire())
            log_error("RD_EN input wire not found");
        rd_en_wc = rd_data_ff_en.as_wire();
        if (!rd_data_ff_clk.as_wire())
            log_error("RD_CLK input wire not found");
        clk_wc = rd_data_ff_clk.as_wire();
    } else {
        log_error("output FF not found");
    }

    if (rd_addr_and) {
        bool has_wire = false;
        if (rd_addr_and_a.is_wire()) {
            has_wire = true;
            rd_addr_and_a_wc = rd_addr_and_a.as_wire();
        }
        if (rd_addr_and_b.is_wire()) {
            has_wire = true;
            rd_addr_and_b_wc = rd_addr_and_b.as_wire();
        }
        if (!has_wire)
            log_error("RD_ADDR $and cell input wire not found");
    } else {
        log_debug("RD_ADDR $and cell not found");
    }

    RTLIL::Wire *wr_addr_wc;
    if (wr_addr_ff) {
        if (!wr_addr_ff_d.as_wire())
            log_error("WR_ADDR input wire not found");
        wr_addr_wc = wr_addr_ff_d.as_wire();
    } else {
        if (!mem_wr_addr.as_wire())
            log_error("WR_ADDR input wire not found");
        wr_addr_wc = mem_wr_addr.as_wire();
    }

    if (!mem_rd_addr.as_wire())
        log_error("RD_ADDR input wire not found");
    auto rd_addr_wc = mem_rd_addr.as_wire();
    if (!mem_wr_data.as_wire())
        log_error("WR_DATA input wire not found");
    auto wr_data_wc = mem_wr_data.as_wire();

    // Check if wr_en_and cell has one of its inputs connected to write address

    // Compare and assign wires
    RTLIL::Wire *rd_addr_w = nullptr;
    RTLIL::Wire *rd_data_w = nullptr;
    RTLIL::Wire *rd_en_w = nullptr;
    RTLIL::Wire *rd_clk_w = nullptr;
    RTLIL::Wire *wr_addr_w = nullptr;
    RTLIL::Wire *wr_data_w = nullptr;

    for (auto wire : pm.module->wires_) {
        if (wire.second == rd_addr_wc)
            rd_addr_w = wire.second;
        if (wire.second == rd_data_wc)
            rd_data_w = wire.second;
        if (wire.second == rd_en_wc)
            rd_en_w = wire.second;
        if (wire.second == clk_wc)
            rd_clk_w = wire.second;
        if (wire.second == wr_addr_wc)
            wr_addr_w = wire.second;
        if (wire.second == wr_data_wc)
            wr_data_w = wire.second;
    }

    if (!rd_addr_w | !rd_data_w | !rd_en_w | !rd_clk_w | !wr_addr_w | !wr_data_w)
        log_error("Match between RAM input wires and memory cell ports not found\n");

    // Set shift output SigSpec as RD_DATA
    cell->setPort(RTLIL::escape_id("RD_DATA"), rd_data_shift_y);

    // Get address and data lines widths
    int rd_addr_width = rd_addr_w->width;
    int wr_addr_width = wr_addr_w->width;
    int wr_data_width = wr_data_w->width;
    int rd_data_width = rd_data_w->width;

    log_debug("Set RD_ADDR_WIDTH = %d, ", rd_addr_width);
    log_debug("WR_ADDR_WIDTH = %d, ", wr_addr_width);
    log_debug("RD_DATA_WIDTH = %d, ", rd_data_width);
    log_debug("WR_DATA_WIDTH = %d\n", wr_data_width);

    // Set address and data lines width parameters used later in techmap
    cell->setParam(RTLIL::escape_id("RD_ADDR_WIDTH"), RTLIL::Const(rd_addr_width));
    cell->setParam(RTLIL::escape_id("RD_DATA_WIDTH"), RTLIL::Const(rd_data_width));
    cell->setParam(RTLIL::escape_id("WR_ADDR_WIDTH"), RTLIL::Const(wr_addr_width));
    cell->setParam(RTLIL::escape_id("WR_DATA_WIDTH"), RTLIL::Const(wr_data_width));

    // Bypass read address shift and connect line straight to memory cell
    auto rd_addr_s = RTLIL::SigSpec(rd_addr_w);
    cell->setPort(RTLIL::escape_id("RD_ADDR"), rd_addr_s);

    if (wr_addr_ff) {
        // Bypass FF on write address line if exists
        // wr_addr_ff_d will not be assigned if wr_addr_ff was not detected earlier
        cell->setPort(RTLIL::escape_id("WR_ADDR"), wr_addr_ff_d);
    } else {
        // When there are no regs on address lines, the clock isn't connected to memory
        // Reconnect the clock
        auto rd_clk_s = RTLIL::SigSpec(rd_clk_w);
        cell->setPort(RTLIL::escape_id("RD_CLK"), rd_clk_s);
    }

    // Bypass FF on Data Output and connect the output straight to RD_DATA port
    cell->setPort(RTLIL::escape_id("RD_DATA"), rd_data_ff_q);

    // Bypass MUX on WRITE ENABLE and connect the output straight to WR_EN port
    cell->setPort(RTLIL::escape_id("WR_EN"), wr_en_mux_s);

    // Connect Read Enable signal to memory cell
    if (!rd_en_w)
        log_error("Wire \\rce not found");
    auto rd_en_s = RTLIL::SigSpec(rd_en_w);
    cell->setPort(RTLIL::escape_id("RD_EN"), rd_en_s);

    // Cleanup the module from unused cells
    pm.module->remove(mem);
    pm.module->remove(rd_data_shift);
    pm.module->remove(rd_data_ff);
    pm.module->remove(wr_en_mux);
    if (wr_addr_ff)
        pm.module->remove(wr_addr_ff);
    // Check if detected $and is connected to RD_ADDR
    if ((rd_addr_and_a_wc != rd_addr_w) & (rd_addr_and_b_wc != rd_addr_w))
        log_error("This is not the $and cell we are looking for");
    else
        pm.module->remove(rd_addr_and);
}

struct QLBramAsymmetric : public Pass {

    QLBramAsymmetric()
        : Pass("ql_bram_asymmetric",
               "Detects memory cells with asymmetric read and write port widths implemented with shifts and infers custom asymmetric memory cell")
    {
    }

    void help() override
    {
        log("\n");
        log("    ql_bram_asymmetric\n");
        log("\n");
        log("		Detects memory cells with asymmetric read and write port widths implemented with shifts and infers custom asymmetric memory "
            "cell");
        log("\n");
    }

    void execute(std::vector<std::string> a_Args, RTLIL::Design *a_Design) override
    {
        log_header(a_Design, "Executing QL_BRAM_ASYMMETRIC pass.\n");

        size_t argidx;
        for (argidx = 1; argidx < a_Args.size(); argidx++) {
            break;
        }
        extra_args(a_Args, argidx, a_Design);

        int found_cells;
        for (auto module : a_Design->selected_modules()) {
            found_cells = ql_bram_asymmetric_wider_write_pm(module, module->selected_cells())
                            .run_ql_bram_asymmetric_wider_write(test_ql_bram_asymmetric_wider_write);
            log_debug("found %d cells matching for wider write port\n", found_cells);
            found_cells = ql_bram_asymmetric_wider_read_pm(module, module->selected_cells())
                            .run_ql_bram_asymmetric_wider_read(test_ql_bram_asymmetric_wider_read);
            log_debug("found %d cells matching for wider read port\n", found_cells);
        }
    }
} QLBramAsymmetric;

PRIVATE_NAMESPACE_END
