/*
 *  yosys -- Yosys Open SYnthesis Suite
 *
 *  Copyright (C) 2021 Lalit Sharma <lsharma@quicklogic.com>
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
 *
 */
#include "kernel/celltypes.h"
#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/rtlil.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

struct SynthQuickLogicPass : public ScriptPass {

    SynthQuickLogicPass() : ScriptPass("synth_quicklogic", "Synthesis for QuickLogic FPGAs") {}

    void help() override
    {
        log("\n");
        log("   synth_quicklogic [options]\n");
        log("This command runs synthesis for QuickLogic FPGAs\n");
        log("\n");
        log("    -top <module>\n");
        log("         use the specified module as top module\n");
        log("\n");
        log("    -family <family>\n");
        log("        run synthesis for the specified QuickLogic architecture\n");
        log("        generate the synthesis netlist for the specified family.\n");
        log("        supported values:\n");
        log("        - qlf_k4n8: qlf_k4n8 \n");
        log("\n");
        log("    -no_abc_opt\n");
        log("        By default most of ABC logic optimization features is\n");
        log("        enabled. Specifying this switch turns them off.\n");
        log("\n");
        log("    -edif <file>\n");
        log("        write the design to the specified edif file. writing of an output file\n");
        log("        is omitted if this parameter is not specified.\n");
        log("\n");
        log("    -blif <file>\n");
        log("        write the design to the specified BLIF file. writing of an output file\n");
        log("        is omitted if this parameter is not specified.\n");
        log("\n");
        log("    -verilog <file>\n");
        log("        write the design to the specified verilog file. writing of an output file\n");
        log("        is omitted if this parameter is not specified.\n");
        log("\n");
        log("    -no_adder\n");
        log("        By default use adder cells in output netlist.\n");
        log("        Specifying this switch turns it off.\n");
        log("\n");
        log("    -no_bram\n");
        log("        By default use Block RAM in output netlist.\n");
        log("        Specifying this switch turns it off.\n");
        log("\n");
        log("    -no_ff_map\n");
        log("        By default ff techmap is turned on. Specifying this switch turns it off.\n");
        log("\n");
        log("\n");
        log("The following commands are executed by this synthesis command:\n");
        help_script();
        log("\n");
    }

    string top_opt, edif_file, blif_file, family, currmodule, verilog_file;
    bool inferAdder;
    bool inferBram;
    bool abcOpt;
    bool noffmap;

    void clear_flags() override
    {
        top_opt = "-auto-top";
        edif_file = "";
        blif_file = "";
        verilog_file = "";
        currmodule = "";
        family = "qlf_k4n8";
        inferAdder = true;
        inferBram = true;
        abcOpt = true;
        noffmap = false;
    }

    void execute(std::vector<std::string> args, RTLIL::Design *design) override
    {
        string run_from, run_to;
        clear_flags();

        size_t argidx;
        for (argidx = 1; argidx < args.size(); argidx++) {
            if (args[argidx] == "-top" && argidx + 1 < args.size()) {
                top_opt = "-top " + args[++argidx];
                continue;
            }
            if (args[argidx] == "-edif" && argidx + 1 < args.size()) {
                edif_file = args[++argidx];
                continue;
            }

            if (args[argidx] == "-family" && argidx + 1 < args.size()) {
                family = args[++argidx];
                continue;
            }
            if (args[argidx] == "-blif" && argidx + 1 < args.size()) {
                blif_file = args[++argidx];
                continue;
            }
            if (args[argidx] == "-verilog" && argidx + 1 < args.size()) {
                verilog_file = args[++argidx];
                continue;
            }
            if (args[argidx] == "-no_adder") {
                inferAdder = false;
                continue;
            }
            if (args[argidx] == "-no_bram") {
                inferBram = false;
                continue;
            }
            if (args[argidx] == "-no_abc_opt") {
                abcOpt = false;
                continue;
            }
            if (args[argidx] == "-no_ff_map") {
                noffmap = true;
                continue;
            }

            break;
        }
        extra_args(args, argidx, design);

        if (!design->full_selection())
            log_cmd_error("This command only operates on fully selected designs!\n");

        log_header(design, "Executing SYNTH_QUICKLOGIC pass.\n");
        log_push();

        run_script(design, run_from, run_to);

        log_pop();
    }

    void script() override
    {
        if (check_label("begin")) {
            std::string readVelArgs;
            readVelArgs = " +/quicklogic/" + family + "_cells_sim.v";

            run("read_verilog -lib -specify +/quicklogic/cells_sim.v" + readVelArgs);
            run(stringf("hierarchy -check %s", help_mode ? "-top <top>" : top_opt.c_str()));
        }

        if (check_label("prepare")) {
            run("proc");
            run("flatten");
            run("opt_expr");
            run("opt_clean");
            run("deminout");
            run("opt");
        }

        if (check_label("coarse")) {
            run("opt_expr");
            run("opt_clean");
            run("check");
            run("opt");
            run("wreduce -keepdc");
            run("peepopt");
            run("pmuxtree");
            run("opt_clean");

            run("alumacc");
            run("opt");
            run("fsm");
            run("opt -fast");
            run("memory -nomap");
            run("opt_clean");
        }

        if (check_label("map_bram", "(skip if -no_bram)") && family == "qlf_k6n10" && inferBram) {
            run("memory_bram -rules +/quicklogic/" + family + "_brams.txt");
            run("techmap -map +/quicklogic/" + family + "_brams_map.v");
        }

        if (check_label("map_ffram")) {
            run("opt -fast -mux_undef -undriven -fine");
            run("memory_map -iattr -attr !ram_block -attr !rom_block -attr logic_block "
                "-attr syn_ramstyle=auto -attr syn_ramstyle=registers "
                "-attr syn_romstyle=auto -attr syn_romstyle=logic");
            run("opt -undriven -fine");
        }

        if (check_label("map_gates")) {
            if (inferAdder) {
                run("techmap -map +/techmap.v -map +/quicklogic/" + family + "_arith_map.v");
            } else {
                run("techmap");
            }
            run("opt -fast");
            run("opt_expr");
            run("opt_merge");
            run("opt_clean");
            run("opt");
        }

        if (check_label("map_ffs")) {
            if (family == "qlf_k4n8") {
                run("shregmap -minlen 8 -maxlen 8");
            }
            if (family == "qlf_k6n10") {
                run("dfflegalize -cell $_DFF_P_ 0");
            } else {
                run("dfflegalize -cell $_DFF_P_ 0 -cell $_DFF_P??_ 0 -cell $_DFF_N_ 0 -cell $_DFF_N??_ 0 -cell $_DFFSR_???_ 0");
            }
            std::string techMapArgs = " -map +/techmap.v -map +/quicklogic/" + family + "_ffs_map.v";
            if (!noffmap) {
                run("techmap " + techMapArgs);
            }
            run("opt_merge");
            run("opt_clean");
            run("opt");
        }

        if (check_label("map_luts")) {
            if (family == "qlf_k6n10") {
                run("abc -lut 6 ");
            } else {
                run("abc -lut 4 ");
            }
            run("clean");
            run("opt_lut");
        }

        if (check_label("map_cells") && family == "qlf_k6n10") {
            std::string techMapArgs;
            techMapArgs = "-map +/quicklogic/" + family + "_lut_map.v";
            run("techmap " + techMapArgs);
            run("clean");
        }

        if (check_label("check")) {
            run("autoname");
            run("hierarchy -check");
            run("stat");
            run("check -noinit");
        }

        if (check_label("finalize")) {
            run("check");
            run("opt_clean -purge");
        }

        if (check_label("edif")) {
            if (!edif_file.empty())
                run(stringf("write_edif -nogndvcc -attrprop -pvector par %s %s", this->currmodule.c_str(), edif_file.c_str()));
        }

        if (check_label("blif")) {
            if (!blif_file.empty()) {
                if (inferAdder) {
                    run(stringf("write_blif -param %s", help_mode ? "<file-name>" : blif_file.c_str()));
                } else {
                    run(stringf("write_blif %s", help_mode ? "<file-name>" : blif_file.c_str()));
                }
            }
        }

        if (check_label("verilog")) {
            if (!verilog_file.empty()) {
                run("write_verilog -noattr -nohex " + verilog_file);
            }
        }
    }

} SynthQuicklogicPass;

PRIVATE_NAMESPACE_END
