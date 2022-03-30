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
#include "kernel/celltypes.h"
#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/rtlil.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

#define XSTR(val) #val
#define STR(val) XSTR(val)

#ifndef PASS_NAME
#define PASS_NAME synth_quicklogic
#endif

struct SynthQuickLogicPass : public ScriptPass {

    SynthQuickLogicPass() : ScriptPass(STR(PASS_NAME), "Synthesis for QuickLogic FPGAs") {}

    void help() override
    {
        log("\n");
        log("   %s [options]\n", STR(PASS_NAME));
        log("This command runs synthesis for QuickLogic FPGAs\n");
        log("\n");
        log("    -top <module>\n");
        log("         use the specified module as top module\n");
        log("\n");
        log("    -family <family>\n");
        log("        run synthesis for the specified QuickLogic architecture\n");
        log("        generate the synthesis netlist for the specified family.\n");
        log("        supported values:\n");
        log("        - pp3      : pp3 \n");
        log("        - qlf_k4n8 : qlf_k4n8 \n");
        log("        - qlf_k6n10: qlf_k6n10 \n");
        log("        - qlf_k6n10f: qlf_k6n10f \n");
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
        log("    -no_dsp\n");
        log("        By default use DSP blocks in output netlist.\n");
        log("        do not use DSP blocks to implement multipliers and associated logic\n");
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
    bool nodsp;
    bool inferAdder;
    bool inferBram;
    bool abcOpt;
    bool abc9;
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
        abc9 = true;
        noffmap = false;
        nodsp = false;
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
            if (args[argidx] == "-no_dsp") {
                nodsp = true;
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
            if (args[argidx] == "-no_abc9") {
                abc9 = false;
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

        if (family != "pp3" && family != "qlf_k4n8" && family != "qlf_k6n10" && family != "qlf_k6n10f")
            log_cmd_error("Invalid family specified: '%s'\n", family.c_str());

        if (family != "pp3") {
            abc9 = false;
        }

        if (abc9 && design->scratchpad_get_int("abc9.D", 0) == 0) {
            log_warning("delay target has not been set via SDC or scratchpad; assuming 12 MHz clock.\n");
            design->scratchpad_set_int("abc9.D", 41667); // 12MHz = 83.33.. ns; divided by two to allow for interconnect delay.
        }

        log_header(design, "Executing SYNTH_QUICKLOGIC pass.\n");
        log_push();

        run_script(design, run_from, run_to);

        log_pop();
    }

    void script() override
    {
        if (check_label("begin")) {
            std::string readVelArgs;
            readVelArgs = " +/quicklogic/" + family + "/cells_sim.v";

            // Use -nomem2reg here to prevent Yosys from complaining about
            // some block ram cell models. After all the only part of the cells
            // library required here is cell port definitions plus specify blocks.
            run("read_verilog -lib -specify -nomem2reg +/quicklogic/common/cells_sim.v" + readVelArgs);
            run(stringf("hierarchy -check %s", help_mode ? "-top <top>" : top_opt.c_str()));
        }

        if (check_label("prepare")) {
            run("proc");
            run("flatten");
            if (family == "pp3") {
                run("tribuf -logic");
            }
            run("deminout");
            run("opt_expr");
            run("opt_clean");
        }

        std::string noDFFArgs;
        if (family == "qlf_k4n8") {
            noDFFArgs = " -nodffe -nosdff";
        } else if (family == "qlf_k6n10f") {
            noDFFArgs = " -nosdff";
        }

        if (check_label("coarse")) {
            run("check");
            run("opt -nodffe -nosdff");
            run("fsm");
            run("opt" + noDFFArgs);
            run("wreduce");
            run("peepopt");
            run("opt_clean");
            run("share");

            if (family == "qlf_k6n10") {
                if (help_mode || !nodsp) {
                    run("memory_dff");
                    run("wreduce t:$mul");
                    run("techmap -map +/mul2dsp.v -map +/quicklogic/" + family +
                          "/dsp_map.v -D DSP_A_MAXWIDTH=16 -D DSP_B_MAXWIDTH=16 "
                          "-D DSP_A_MINWIDTH=2 -D DSP_B_MINWIDTH=2 -D DSP_Y_MINWIDTH=11 "
                          "-D DSP_NAME=$__MUL16X16",
                        "(for qlf_k6n10 if not -no_dsp)");
                    run("select a:mul2dsp", "              (for qlf_k6n10 if not -no_dsp)");
                    run("setattr -unset mul2dsp", "        (for qlf_k6n10 if not -no_dsp)");
                    run("opt_expr -fine", "                (for qlf_k6n10 if not -no_dsp)");
                    run("wreduce", "                       (for qlf_k6n10 if not -no_dsp)");
                    run("select -clear", "                 (for qlf_k6n10 if not -no_dsp)");
                    run("ql_dsp", "                        (for qlf_k6n10 if not -no_dsp)");
                    run("chtype -set $mul t:$__soft_mul", "(for qlf_k6n10 if not -no_dsp)");
                }
            } else if (family == "qlf_k6n10f") {

                struct DspParams {
                    size_t a_maxwidth;
                    size_t b_maxwidth;
                    size_t a_minwidth;
                    size_t b_minwidth;
                    std::string type;
                };

                const std::vector<DspParams> dsp_rules = {
                  {20, 18, 11, 10, "$__QL_MUL20X18"},
                  {10, 9, 4, 4, "$__QL_MUL10X9"},
                };

                if (help_mode) {
                    run("wreduce t:$mul", "                (for qlf_k6n10f if not -no_dsp)");
                    run("ql_dsp_macc", "                   (for qlf_k6n10f if not -no_dsp)");
                    run("techmap -map +/mul2dsp.v [...]", "(for qlf_k6n10f if not -no_dsp)");
                    run("chtype -set $mul t:$__soft_mul", "(for qlf_k6n10f if not -no_dsp)");
                    run("techmap -map +/quicklogic/" + family + "/dsp_map.v", "(for qlf_k6n10f if not -no_dsp)");
                    run("ql_dsp_simd                   ", "(for qlf_k6n10f if not -no_dsp)");
                    run("techmap -map +/quicklogic/" + family + "/dsp_final_map.v", "(for qlf_k6n10f if not -no_dsp)");
                } else if (!nodsp) {

                    run("wreduce t:$mul");
                    run("ql_dsp_macc");

                    for (const auto &rule : dsp_rules) {
                        run(stringf("techmap -map +/mul2dsp.v "
                                    "-D DSP_A_MAXWIDTH=%zu -D DSP_B_MAXWIDTH=%zu "
                                    "-D DSP_A_MINWIDTH=%zu -D DSP_B_MINWIDTH=%zu "
                                    "-D DSP_NAME=%s",
                                    rule.a_maxwidth, rule.b_maxwidth, rule.a_minwidth, rule.b_minwidth, rule.type.c_str()));
                        run("chtype -set $mul t:$__soft_mul");
                    }
                    run("techmap -map +/quicklogic/" + family + "/dsp_map.v");
                    run("ql_dsp_simd");
                    run("techmap -map +/quicklogic/" + family + "/dsp_final_map.v");
                }
            }

            run("techmap -map +/cmp2lut.v -D LUT_WIDTH=4");
            run("opt_expr");
            run("opt_clean");
            run("alumacc");
            run("pmuxtree");
            run("opt" + noDFFArgs);
            run("memory -nomap");
            run("opt_clean");
        }

        if (check_label("map_bram", "(skip if -no_bram)") && (family == "qlf_k6n10" || family == "qlf_k6n10f" || family == "pp3") && inferBram) {
            run("memory_bram -rules +/quicklogic/" + family + "/brams.txt");
            if (family == "pp3") {
                run("pp3_braminit");
            }
            run("techmap -map +/quicklogic/" + family + "/brams_map.v");
        }

        if (check_label("map_ffram")) {
            run("opt -fast -mux_undef -undriven -fine" + noDFFArgs);
            run("memory_map -iattr -attr !ram_block -attr !rom_block -attr logic_block "
                "-attr syn_ramstyle=auto -attr syn_ramstyle=registers "
                "-attr syn_romstyle=auto -attr syn_romstyle=logic");
            run("opt -undriven -fine" + noDFFArgs);
        }

        if (check_label("map_gates")) {
            if (inferAdder && (family == "qlf_k4n8" || family == "qlf_k6n10" || family == "qlf_k6n10f")) {
                run("techmap -map +/techmap.v -map +/quicklogic/" + family + "/arith_map.v");
            } else {
                run("techmap");
            }
            run("opt -fast" + noDFFArgs);
            if (family == "pp3") {
                run("muxcover -mux8 -mux4");
            }
            run("opt_expr");
            run("opt_merge");
            run("opt_clean");
            run("opt" + noDFFArgs);
        }

        if (check_label("map_ffs")) {
            run("opt_expr");
            if (family == "qlf_k4n8") {
                run("shregmap -minlen 8 -maxlen 8");
                run("dfflegalize -cell $_DFF_P_ 0 -cell $_DFF_P??_ 0 -cell $_DFF_N_ 0 -cell $_DFF_N??_ 0 -cell $_DFFSR_???_ 0");
            } else if (family == "qlf_k6n10") {
                run("dfflegalize -cell $_DFF_P_ 0 -cell $_DFF_PP?_ 0 -cell $_DFFE_PP?P_ 0 -cell $_DFFSR_PPP_ 0 -cell $_DFFSRE_PPPP_ 0 -cell "
                    "$_DLATCHSR_PPP_ 0");
                //    In case we add clock inversion in the future.
                //    run("dfflegalize -cell $_DFF_?_ 0 -cell $_DFF_?P?_ 0 -cell $_DFFE_?P?P_ 0 -cell $_DFFSR_?PP_ 0 -cell $_DFFSRE_?PPP_ 0 -cell
                //    $_DLATCH_SRPPP_ 0");
            } else if (family == "qlf_k6n10f") {
                run("shregmap -minlen 8 -maxlen 20");
                run("dfflegalize -cell $_DFF_?_ 0 -cell $_DFF_???_ 0 -cell $_DFFE_????_ 0 -cell $_DFFSR_???_ 0 -cell $_DFFSRE_????_ 0 -cell "
                    "$_DLATCHSR_PPP_ 0");
            } else if (family == "pp3") {
                run("dfflegalize -cell $_DFFSRE_PPPP_ 0 -cell $_DLATCH_?_ x");
                run("techmap -map +/quicklogic/" + family + "/cells_map.v");
            }
            std::string techMapArgs = " -map +/techmap.v -map +/quicklogic/" + family + "/ffs_map.v";
            if (!noffmap) {
                run("techmap " + techMapArgs);
            }
            if (family == "pp3") {
                run("opt_expr -mux_undef");
            }
            run("opt_merge");
            run("opt_clean");
            run("opt" + noDFFArgs);
        }

        if (check_label("map_luts")) {
            if (abcOpt) {
                if (family == "qlf_k6n10" || family == "qlf_k6n10f") {
                    run("abc -lut 6 ");
                } else if (family == "qlf_k4n8") {
                    run("abc -lut 4 ");
                } else if (family == "pp3") {
                    run("techmap -map +/quicklogic/" + family + "/latches_map.v");
                    if (abc9) {
                        run("read_verilog -lib -specify -icells +/quicklogic/" + family + "/abc9_model.v");
                        run("techmap -map +/quicklogic/" + family + "/abc9_map.v");
                        run("abc9 -maxlut 4 -dff");
                        run("techmap -map +/quicklogic/" + family + "/abc9_unmap.v");
                    } else {
                        std::string lutDefs = "+/quicklogic/" + family + "/lutdefs.txt";
                        rewrite_filename(lutDefs);

                        std::string abcArgs = "+read_lut," + lutDefs +
                                              ";"
                                              "strash;ifraig;scorr;dc2;dretime;strash;dch,-f;if;mfs2;" // Common Yosys ABC script
                                              "sweep;eliminate;if;mfs;lutpack;"                        // Optimization script
                                              "dress";                                                 // "dress" to preserve names

                        run("abc -script " + abcArgs);
                    }
                }
            }
            run("clean");
            run("opt_lut");
        }

        if (check_label("map_cells") && (family == "qlf_k6n10" || family == "pp3")) {
            std::string techMapArgs;
            techMapArgs = "-map +/quicklogic/" + family + "/lut_map.v";
            run("techmap " + techMapArgs);
            run("clean");
        }

        if (check_label("check")) {
            run("autoname");
            run("hierarchy -check");
            run("stat");
            run("check -noinit");
        }

        if (check_label("iomap") && family == "pp3") {
            run("clkbufmap -inpad ckpad Q:P");
            run("iopadmap -bits -outpad outpad A:P -inpad inpad Q:P -tinoutpad bipad EN:Q:A:P A:top");
        }

        if (check_label("finalize")) {
            if (family == "pp3") {
                run("setundef -zero -params -undriven");
            }
            if (family == "pp3" || (check_label("edif") && (!edif_file.empty()))) {
                run("hilomap -hicell logic_1 a -locell logic_0 a -singleton A:top");
            }
            run("opt_clean -purge");
            run("check");
            run("blackbox =A:whitebox");
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

        if (check_label("edif") && (!edif_file.empty())) {
            run("splitnets -ports -format ()");
            run("quicklogic_eqn");

            run(stringf("write_ql_edif -nogndvcc -attrprop -pvector par %s %s", this->currmodule.c_str(), edif_file.c_str()));
        }

        if (check_label("verilog")) {
            if (!verilog_file.empty()) {
                run("write_verilog -noattr -nohex " + verilog_file);
            }
        }
    }

} SynthQuicklogicPass;

PRIVATE_NAMESPACE_END
