// Copyright 2020-2022 F4PGA Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

(* blackbox *)
module QL_DSP1 (
    input wire [19:0] a,
    input wire [17:0] b,
    (* clkbuf_sink *)
    input wire clk0,
    (* clkbuf_sink *)
    input wire clk1,
    input wire [ 1:0] feedback0,
    input wire [ 1:0] feedback1,
    input wire        load_acc0,
    input wire        load_acc1,
    input wire        reset0,
    input wire        reset1,
    output reg [37:0] z
);
    parameter MODE_BITS = 27'b00000000000000000000000000;
endmodule  /* QL_DSP1 */



// ---------------------------------------- //
// ----- DSP cells simulation modules ----- //
// --------- Control bits in ports -------- //
// ---------------------------------------- //

module QL_DSP2 ( // TODO: Name subject to change
    input  wire [19:0] a,
    input  wire [17:0] b,
    input  wire [ 5:0] acc_fir,
    output wire [37:0] z,
    output wire [17:0] dly_b,

    (* clkbuf_sink *)
    input  wire       clk,
    input  wire       reset,

    input  wire [2:0] feedback,
    input  wire       load_acc,
    input  wire       unsigned_a,
    input  wire       unsigned_b,

    input  wire       f_mode,
    input  wire [2:0] output_select,
    input  wire       saturate_enable,
    input  wire [5:0] shift_right,
    input  wire       round,
    input  wire       subtract,
    input  wire       register_inputs
);

    parameter [79:0] MODE_BITS = 80'd0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    localparam NBITS_ACC = 64;
    localparam NBITS_A = 20;
    localparam NBITS_B = 18;
    localparam NBITS_Z = 38;

    wire [NBITS_Z-1:0] dsp_full_z;
    wire [(NBITS_Z/2)-1:0] dsp_frac0_z;
    wire [(NBITS_Z/2)-1:0] dsp_frac1_z;

    wire [NBITS_B-1:0] dsp_full_dly_b;
    wire [(NBITS_B/2)-1:0] dsp_frac0_dly_b;
    wire [(NBITS_B/2)-1:0] dsp_frac1_dly_b;

    assign z = f_mode ? {dsp_frac1_z, dsp_frac0_z} : dsp_full_z;
    assign dly_b = f_mode ? {dsp_frac1_dly_b, dsp_frac0_dly_b} : dsp_full_dly_b;

    // Output used when fmode == 1
        dsp_t1_sim_cfg_ports #(
        .NBITS_A(NBITS_A/2),
            .NBITS_B(NBITS_B/2),
            .NBITS_ACC(NBITS_ACC/2),
            .NBITS_Z(NBITS_Z/2)
        ) dsp_frac0 (
            .a_i(a[(NBITS_A/2)-1:0]),
            .b_i(b[(NBITS_B/2)-1:0]),
            .z_o(dsp_frac0_z),
            .dly_b_o(dsp_frac0_dly_b),

            .acc_fir_i(acc_fir),
            .feedback_i(feedback),
            .load_acc_i(load_acc),

            .unsigned_a_i(unsigned_a),
            .unsigned_b_i(unsigned_b),

            .clock_i(clk),
            .s_reset(reset),

            .saturate_enable_i(saturate_enable),
            .output_select_i(output_select),
            .round_i(round),
            .shift_right_i(shift_right),
            .subtract_i(subtract),
            .register_inputs_i(register_inputs),
            .coef_0_i(COEFF_0[(NBITS_A/2)-1:0]),
            .coef_1_i(COEFF_1[(NBITS_A/2)-1:0]),
            .coef_2_i(COEFF_2[(NBITS_A/2)-1:0]),
            .coef_3_i(COEFF_3[(NBITS_A/2)-1:0])
        );

    // Output used when fmode == 1
        dsp_t1_sim_cfg_ports #(
        .NBITS_A(NBITS_A/2),
            .NBITS_B(NBITS_B/2),
            .NBITS_ACC(NBITS_ACC/2),
            .NBITS_Z(NBITS_Z/2)
        ) dsp_frac1 (
            .a_i(a[NBITS_A-1:NBITS_A/2]),
            .b_i(b[NBITS_B-1:NBITS_B/2]),
            .z_o(dsp_frac1_z),
            .dly_b_o(dsp_frac1_dly_b),

            .acc_fir_i(acc_fir),
            .feedback_i(feedback),
            .load_acc_i(load_acc),

            .unsigned_a_i(unsigned_a),
            .unsigned_b_i(unsigned_b),

            .clock_i(clk),
            .s_reset(reset),

            .saturate_enable_i(saturate_enable),
            .output_select_i(output_select),
            .round_i(round),
            .shift_right_i(shift_right),
            .subtract_i(subtract),
            .register_inputs_i(register_inputs),
            .coef_0_i(COEFF_0[NBITS_A-1:NBITS_A/2]),
            .coef_1_i(COEFF_1[NBITS_A-1:NBITS_A/2]),
            .coef_2_i(COEFF_2[NBITS_A-1:NBITS_A/2]),
            .coef_3_i(COEFF_3[NBITS_A-1:NBITS_A/2])
        );

    // Output used when fmode == 0
        dsp_t1_sim_cfg_ports #(
            .NBITS_A(NBITS_A),
            .NBITS_B(NBITS_B),
            .NBITS_ACC(NBITS_ACC),
            .NBITS_Z(NBITS_Z)
        ) dsp_full (
            .a_i(a),
            .b_i(b),
            .z_o(dsp_full_z),
            .dly_b_o(dsp_full_dly_b),

            .acc_fir_i(acc_fir),
            .feedback_i(feedback),
            .load_acc_i(load_acc),

            .unsigned_a_i(unsigned_a),
            .unsigned_b_i(unsigned_b),

            .clock_i(clk),
            .s_reset(reset),

            .saturate_enable_i(saturate_enable),
            .output_select_i(output_select),
            .round_i(round),
            .shift_right_i(shift_right),
            .subtract_i(subtract),
            .register_inputs_i(register_inputs),
            .coef_0_i(COEFF_0),
            .coef_1_i(COEFF_1),
            .coef_2_i(COEFF_2),
            .coef_3_i(COEFF_3)
        );
endmodule

module QL_DSP2_MULT ( // TODO: Name subject to change
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    input  wire       reset,

    input  wire [2:0] feedback,
    input  wire       unsigned_a,
    input  wire       unsigned_b,

    input  wire       f_mode,
    input  wire [2:0] output_select,
    input  wire       register_inputs
);

    parameter [79:0] MODE_BITS = 80'd0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    QL_DSP2 #(
        .MODE_BITS({COEFF_3, COEFF_2, COEFF_1, COEFF_0})
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .reset(reset),

        .f_mode(f_mode),

        .feedback(feedback),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .output_select(output_select),      // unregistered output: a * b (0)
        .register_inputs(register_inputs)   // unregistered inputs
    );
endmodule

module QL_DSP2_MULT_REGIN ( // TODO: Name subject to change
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire       clk,
    input  wire       reset,

    input  wire [2:0] feedback,
    input  wire       unsigned_a,
    input  wire       unsigned_b,

    input  wire       f_mode,
    input  wire [2:0] output_select,
    input  wire       register_inputs
);

    parameter [79:0] MODE_BITS = 80'd0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    QL_DSP2 #(
        .MODE_BITS({COEFF_3, COEFF_2, COEFF_1, COEFF_0})
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .f_mode(f_mode),

        .feedback(feedback),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset),

        .output_select(output_select),      // unregistered output: a * b (0)
        .register_inputs(register_inputs)   // registered inputs
    );
endmodule

module QL_DSP2_MULT_REGOUT ( // TODO: Name subject to change
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire       clk,
    input  wire       reset,

    input  wire [2:0] feedback,
    input  wire       unsigned_a,
    input  wire       unsigned_b,
    input  wire       f_mode,
    input  wire [2:0] output_select,
    input  wire       register_inputs
);

    parameter [79:0] MODE_BITS = 80'd0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    QL_DSP2 #(
        .MODE_BITS({COEFF_3, COEFF_2, COEFF_1, COEFF_0})
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .f_mode(f_mode),

        .feedback(feedback),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset),

        .output_select(output_select),      // registered output: a * b (4)
        .register_inputs(register_inputs)   // unregistered inputs
    );
endmodule

module QL_DSP2_MULT_REGIN_REGOUT ( // TODO: Name subject to change
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire       clk,
    input  wire       reset,

    input  wire [2:0] feedback,
    input  wire       unsigned_a,
    input  wire       unsigned_b,
    input  wire       f_mode,
    input  wire [2:0] output_select,
    input  wire       register_inputs
);

    parameter [79:0] MODE_BITS = 80'd0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    QL_DSP2 #(
        .MODE_BITS({COEFF_3, COEFF_2, COEFF_1, COEFF_0})
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .f_mode(f_mode),

        .feedback(feedback),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset),

        .output_select(output_select),      // registered output: a * b (4)
        .register_inputs(register_inputs)   // registered inputs
    );
endmodule

module QL_DSP2_MULTADD (
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    input  wire        reset,

    input  wire [ 2:0] feedback,
    input  wire [ 5:0] acc_fir,
    input  wire        load_acc,
    input  wire        unsigned_a,
    input  wire        unsigned_b,

    input  wire        f_mode,
    input  wire [ 2:0] output_select,
    input  wire        subtract,
    input  wire        register_inputs
);

    parameter [79:0] MODE_BITS = 80'd0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    QL_DSP2 #(
        .MODE_BITS({COEFF_3, COEFF_2, COEFF_1, COEFF_0})
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .f_mode(f_mode),

        .feedback(feedback),
        .acc_fir(acc_fir),
        .load_acc(load_acc),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .reset(reset),

        .output_select(output_select),      // unregistered output: ACCin (2, 3)
        .subtract(subtract),
        .register_inputs(register_inputs)   // unregistered inputs
    );
endmodule

module QL_DSP2_MULTADD_REGIN (
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire        clk,
    input  wire        reset,

    input  wire [ 2:0] feedback,
    input  wire [ 5:0] acc_fir,
    input  wire        load_acc,
    input  wire        unsigned_a,
    input  wire        unsigned_b,

    input  wire        f_mode,
    input  wire [ 2:0] output_select,
    input  wire        subtract,
    input  wire        register_inputs
);

    parameter [79:0] MODE_BITS = 80'd0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    QL_DSP2 #(
        .MODE_BITS({COEFF_3, COEFF_2, COEFF_1, COEFF_0})
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .f_mode(f_mode),

        .feedback(feedback),
        .acc_fir(acc_fir),
        .load_acc(load_acc),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset),

        .output_select(output_select),      // unregistered output: ACCin (2, 3)
        .subtract(subtract),
        .register_inputs(register_inputs)   // registered inputs
    );
endmodule

module QL_DSP2_MULTADD_REGOUT (
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire        clk,
    input  wire        reset,

    input  wire [ 2:0] feedback,
    input  wire [ 5:0] acc_fir,
    input  wire        load_acc,
    input  wire        unsigned_a,
    input  wire        unsigned_b,

    input  wire        f_mode,
    input  wire [ 2:0] output_select,
    input  wire        subtract,
    input  wire        register_inputs
);

    parameter [79:0] MODE_BITS = 80'd0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    QL_DSP2 #(
        .MODE_BITS({COEFF_3, COEFF_2, COEFF_1, COEFF_0})
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .f_mode(f_mode),

        .feedback(feedback),
        .acc_fir(acc_fir),
        .load_acc(load_acc),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset),

        .output_select(output_select),      // registered output: ACCin (6, 7)
        .subtract(subtract),
        .register_inputs(register_inputs)   // unregistered inputs
    );
endmodule

module QL_DSP2_MULTADD_REGIN_REGOUT (
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire        clk,
    input  wire        reset,

    input  wire [ 2:0] feedback,
    input  wire [ 5:0] acc_fir,
    input  wire        load_acc,
    input  wire        unsigned_a,
    input  wire        unsigned_b,

    input  wire        f_mode,
    input  wire [ 2:0] output_select,
    input  wire        subtract,
    input  wire        register_inputs
);

    parameter [79:0] MODE_BITS = 80'd0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    QL_DSP2 #(
        .MODE_BITS({COEFF_3, COEFF_2, COEFF_1, COEFF_0})
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .f_mode(f_mode),

        .feedback(feedback),
        .acc_fir(acc_fir),
        .load_acc(load_acc),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset),

        .output_select(output_select),      // registered output: ACCin (6, 7)
        .subtract(subtract),
        .register_inputs(register_inputs)   // registered inputs
    );
endmodule

module QL_DSP2_MULTACC (
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire        clk,
    input  wire        reset,

    input  wire        load_acc,
    input  wire [ 2:0] feedback,
    input  wire        unsigned_a,
    input  wire        unsigned_b,

    input  wire        f_mode,
    input  wire [ 2:0] output_select,
    input  wire        subtract,
    input  wire        register_inputs
);

    parameter [79:0] MODE_BITS = 80'd0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    QL_DSP2 #(
        .MODE_BITS({COEFF_3, COEFF_2, COEFF_1, COEFF_0})
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .f_mode(f_mode),

        .feedback(feedback),
        .load_acc(load_acc),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset),

        .output_select(output_select),      // unregistered output: ACCout (1)
        .subtract(subtract),
        .register_inputs(register_inputs)   // unregistered inputs
    );
endmodule

module QL_DSP2_MULTACC_REGIN (
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire        clk,
    input  wire        reset,

    input  wire [ 2:0] feedback,
    input  wire        load_acc,
    input  wire        unsigned_a,
    input  wire        unsigned_b,

    input  wire        f_mode,
    input  wire [ 2:0] output_select,
    input  wire        subtract,
    input  wire        register_inputs
);

    parameter [79:0] MODE_BITS = 80'd0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    QL_DSP2 #(
        .MODE_BITS({COEFF_3, COEFF_2, COEFF_1, COEFF_0})
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .f_mode(f_mode),

        .feedback(feedback),
        .load_acc(load_acc),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset),

        .output_select(output_select),      // unregistered output: ACCout (1)
        .subtract(subtract),
        .register_inputs(register_inputs)   // registered inputs
    );
endmodule

module QL_DSP2_MULTACC_REGOUT (
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire        clk,
    input  wire        reset,

    input  wire [ 2:0] feedback,
    input  wire        load_acc,
    input  wire        unsigned_a,
    input  wire        unsigned_b,

    input  wire        f_mode,
    input  wire [ 2:0] output_select,
    input  wire        subtract,
    input  wire        register_inputs
);

    parameter [79:0] MODE_BITS = 80'd0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    QL_DSP2 #(
        .MODE_BITS({COEFF_3, COEFF_2, COEFF_1, COEFF_0})
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .f_mode(f_mode),

        .feedback(feedback),
        .load_acc(load_acc),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset),

        .output_select(output_select),      // registered output: ACCout (5)
        .subtract(subtract),
        .register_inputs(register_inputs)   // unregistered inputs
    );
endmodule

module QL_DSP2_MULTACC_REGIN_REGOUT (
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire        clk,
    input  wire        reset,

    input  wire [ 2:0] feedback,
    input  wire        load_acc,
    input  wire        unsigned_a,
    input  wire        unsigned_b,

    input  wire        f_mode,
    input  wire [ 2:0] output_select,
    input  wire        subtract,
    input  wire        register_inputs
);

    parameter [79:0] MODE_BITS = 80'd0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    QL_DSP2 #(
        .MODE_BITS({COEFF_3, COEFF_2, COEFF_1, COEFF_0})
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .f_mode(f_mode),

        .feedback(feedback),
        .load_acc(load_acc),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset),

        .output_select(output_select),      // registered output: ACCout (5)
        .subtract(subtract),
        .register_inputs(register_inputs)   // registered inputs
    );
endmodule

module dsp_t1_20x18x64_cfg_ports (
    input  wire [19:0] a_i,
    input  wire [17:0] b_i,
    input  wire [ 5:0] acc_fir_i,
    output wire [37:0] z_o,
    output wire [17:0] dly_b_o,

    (* clkbuf_sink *)
    input  wire        clock_i,
    input  wire        reset_i,

    input  wire [ 2:0] feedback_i,
    input  wire        load_acc_i,
    input  wire        unsigned_a_i,
    input  wire        unsigned_b_i,

    input  wire [ 2:0] output_select_i,
    input  wire        saturate_enable_i,
    input  wire [ 5:0] shift_right_i,
    input  wire        round_i,
    input  wire        subtract_i,
    input  wire        register_inputs_i
);

    parameter [19:0] COEFF_0 = 20'd0;
    parameter [19:0] COEFF_1 = 20'd0;
    parameter [19:0] COEFF_2 = 20'd0;
    parameter [19:0] COEFF_3 = 20'd0;

    QL_DSP2 #(
        .MODE_BITS({COEFF_3, COEFF_2, COEFF_1, COEFF_0})
    ) dsp (
        .a(a_i),
        .b(b_i),
        .z(z_o),
        .dly_b(dly_b_o),

        .f_mode(1'b0),  // 20x18x64 DSP

        .acc_fir(acc_fir_i),
        .feedback(feedback_i),
        .load_acc(load_acc_i),

        .unsigned_a(unsigned_a_i),
        .unsigned_b(unsigned_b_i),

        .clk(clock_i),
        .reset(reset_i),

        .saturate_enable(saturate_enable_i),
        .output_select(output_select_i),
        .round(round_i),
        .shift_right(shift_right_i),
        .subtract(subtract_i),
        .register_inputs(register_inputs_i)
    );
endmodule

module dsp_t1_10x9x32_cfg_ports (
    input  wire [ 9:0] a_i,
    input  wire [ 8:0] b_i,
    input  wire [ 5:0] acc_fir_i,
    output wire [18:0] z_o,
    output wire [ 8:0] dly_b_o,

    (* clkbuf_sink *)
    input  wire        clock_i,
    input  wire        reset_i,

    input  wire [ 2:0] feedback_i,
    input  wire        load_acc_i,
    input  wire        unsigned_a_i,
    input  wire        unsigned_b_i,

    input  wire [ 2:0] output_select_i,
    input  wire        saturate_enable_i,
    input  wire [ 5:0] shift_right_i,
    input  wire        round_i,
    input  wire        subtract_i,
    input  wire        register_inputs_i
);

    parameter [9:0] COEFF_0 = 10'd0;
    parameter [9:0] COEFF_1 = 10'd0;
    parameter [9:0] COEFF_2 = 10'd0;
    parameter [9:0] COEFF_3 = 10'd0;

    wire [18:0] z_rem;
    wire [8:0] dly_b_rem;

    QL_DSP2 #(
        .MODE_BITS({10'd0, COEFF_3,
                    10'd0, COEFF_2,
                    10'd0, COEFF_1,
                    10'd0, COEFF_0})
    ) dsp (
        .a({10'd0, a_i}),
        .b({9'd0, b_i}),
        .z({z_rem, z_o}),
        .dly_b({dly_b_rem, dly_b_o}),

        .f_mode(1'b1),  // 10x9x32 DSP

        .acc_fir(acc_fir_i),
        .feedback(feedback_i),
        .load_acc(load_acc_i),

        .unsigned_a(unsigned_a_i),
        .unsigned_b(unsigned_b_i),

        .clk(clock_i),
        .reset(reset_i),

        .saturate_enable(saturate_enable_i),
        .output_select(output_select_i),
        .round(round_i),
        .shift_right(shift_right_i),
        .subtract(subtract_i),
        .register_inputs(register_inputs_i)
    );
endmodule

module dsp_t1_sim_cfg_ports # (
    parameter NBITS_ACC  = 64,
    parameter NBITS_A    = 20,
    parameter NBITS_B    = 18,
    parameter NBITS_Z    = 38
)(
    input  wire [NBITS_A-1:0] a_i,
    input  wire [NBITS_B-1:0] b_i,
    output wire [NBITS_Z-1:0] z_o,
    output reg  [NBITS_B-1:0] dly_b_o,

    input  wire [5:0]         acc_fir_i,
    input  wire [2:0]         feedback_i,
    input  wire               load_acc_i,

    input  wire               unsigned_a_i,
    input  wire               unsigned_b_i,

    input  wire               clock_i,
    input  wire               s_reset,

    input  wire               saturate_enable_i,
    input  wire [2:0]         output_select_i,
    input  wire               round_i,
    input  wire [5:0]         shift_right_i,
    input  wire               subtract_i,
    input  wire               register_inputs_i,
    input  wire [NBITS_A-1:0] coef_0_i,
    input  wire [NBITS_A-1:0] coef_1_i,
    input  wire [NBITS_A-1:0] coef_2_i,
    input  wire [NBITS_A-1:0] coef_3_i
);

// FIXME: The version of Icarus Verilog from Conda seems not to recognize the
// $error macro. Disable this sanity check for now because of that.
`ifndef __ICARUS__
    if (NBITS_ACC < NBITS_A + NBITS_B)
        $error("NBITS_ACC must be > NBITS_A + NBITS_B");
`endif

    // Input registers
    reg  [NBITS_A-1:0]  r_a;
    reg  [NBITS_B-1:0]  r_b;
    reg  [5:0]          r_acc_fir;
    reg                 r_unsigned_a;
    reg                 r_unsigned_b;
    reg                 r_load_acc;
    reg  [2:0]          r_feedback;
    reg  [5:0]          r_shift_d1;
    reg  [5:0]          r_shift_d2;
    reg         r_subtract;
    reg         r_sat;
    reg         r_rnd;
    reg [NBITS_ACC-1:0] acc;

    initial begin
        r_a          <= 0;
        r_b          <= 0;

        r_acc_fir    <= 0;
        r_unsigned_a <= 0;
        r_unsigned_b <= 0;
        r_feedback   <= 0;
        r_shift_d1   <= 0;
        r_shift_d2   <= 0;
        r_subtract   <= 0;
        r_load_acc   <= 0;
        r_sat        <= 0;
        r_rnd        <= 0;
    end

    always @(posedge clock_i or posedge s_reset) begin
        if (s_reset) begin

            r_a <= 'h0;
            r_b <= 'h0;

            r_acc_fir    <= 0;
            r_unsigned_a <= 0;
            r_unsigned_b <= 0;
            r_feedback   <= 0;
            r_shift_d1   <= 0;
            r_shift_d2   <= 0;
            r_subtract   <= 0;
            r_load_acc   <= 0;
            r_sat    <= 0;
            r_rnd    <= 0;

        end else begin

            r_a <= a_i;
            r_b <= b_i;

            r_acc_fir    <= acc_fir_i;
            r_unsigned_a <= unsigned_a_i;
            r_unsigned_b <= unsigned_b_i;
            r_feedback   <= feedback_i;
            r_shift_d1   <= shift_right_i;
            r_shift_d2   <= r_shift_d1;
            r_subtract   <= subtract_i;
            r_load_acc   <= load_acc_i;
            r_sat    <= r_sat;
            r_rnd    <= r_rnd;

        end
    end

    // Registered / non-registered input path select
    wire [NBITS_A-1:0]  a = register_inputs_i ? r_a : a_i;
    wire [NBITS_B-1:0]  b = register_inputs_i ? r_b : b_i;

    wire [5:0] acc_fir = register_inputs_i ? r_acc_fir : acc_fir_i;
    wire       unsigned_a = register_inputs_i ? r_unsigned_a : unsigned_a_i;
    wire       unsigned_b = register_inputs_i ? r_unsigned_b : unsigned_b_i;
    wire [2:0] feedback   = register_inputs_i ? r_feedback   : feedback_i;
    wire       load_acc   = register_inputs_i ? r_load_acc   : load_acc_i;
    wire       subtract   = register_inputs_i ? r_subtract   : subtract_i;
    wire       sat    = register_inputs_i ? r_sat : saturate_enable_i;
    wire       rnd    = register_inputs_i ? r_rnd : round_i;

    // Shift right control
    wire [5:0] shift_d1 = register_inputs_i ? r_shift_d1 : shift_right_i;
    wire [5:0] shift_d2 = output_select_i[1] ? shift_d1 : r_shift_d2;

    // Multiplier
    wire unsigned_mode = unsigned_a & unsigned_b;
    wire [NBITS_A-1:0] mult_a;
    assign mult_a = (feedback == 3'h0) ?   a :
                    (feedback == 3'h1) ?   a :
                    (feedback == 3'h2) ?   a :
                    (feedback == 3'h3) ?   acc[NBITS_A-1:0] :
                    (feedback == 3'h4) ?   coef_0_i :
                    (feedback == 3'h5) ?   coef_1_i :
                    (feedback == 3'h6) ?   coef_2_i :
                       coef_3_i;    // if feedback == 3'h7

    wire [NBITS_B-1:0] mult_b = (feedback == 2'h2) ? {NBITS_B{1'b0}}  : b;

    wire [NBITS_A-1:0] mult_sgn_a = mult_a[NBITS_A-1];
    wire [NBITS_A-1:0] mult_mag_a = (mult_sgn_a && !unsigned_a) ? (~mult_a + 1) : mult_a;
    wire [NBITS_B-1:0] mult_sgn_b = mult_b[NBITS_B-1];
    wire [NBITS_B-1:0] mult_mag_b = (mult_sgn_b && !unsigned_b) ? (~mult_b + 1) : mult_b;

    wire [NBITS_A+NBITS_B-1:0] mult_mag = mult_mag_a * mult_mag_b;
    wire mult_sgn = (mult_sgn_a && !unsigned_a) ^ (mult_sgn_b && !unsigned_b);

    wire [NBITS_A+NBITS_B-1:0] mult = (unsigned_a && unsigned_b) ?
        (mult_a * mult_b) : (mult_sgn ? (~mult_mag + 1) : mult_mag);

    // Sign extension
    wire [NBITS_ACC-1:0] mult_xtnd = unsigned_mode ?
        {{(NBITS_ACC-NBITS_A-NBITS_B){1'b0}},                    mult[NBITS_A+NBITS_B-1:0]} :
        {{(NBITS_ACC-NBITS_A-NBITS_B){mult[NBITS_A+NBITS_B-1]}}, mult[NBITS_A+NBITS_B-1:0]};

    // Adder
    wire [NBITS_ACC-1:0] acc_fir_int = unsigned_a ? {{(NBITS_ACC-NBITS_A){1'b0}},         a} :
                                                    {{(NBITS_ACC-NBITS_A){a[NBITS_A-1]}}, a} ;

    wire [NBITS_ACC-1:0] add_a = (subtract) ? (~mult_xtnd + 1) : mult_xtnd;
    wire [NBITS_ACC-1:0] add_b = (feedback_i == 3'h0) ? acc :
                                 (feedback_i == 3'h1) ? {{NBITS_ACC}{1'b0}} : (acc_fir_int << acc_fir);

    wire [NBITS_ACC-1:0] add_o = add_a + add_b;

    // Accumulator
    initial acc <= 0;

    always @(posedge clock_i or posedge s_reset)
        if (s_reset) acc <= 'h0;
        else begin
            if (load_acc)
                acc <= add_o;
            else
                acc <= acc;
        end

    // Adder/accumulator output selection
    wire [NBITS_ACC-1:0] acc_out = (output_select_i[1]) ? add_o : acc;

    // Round, shift, saturate
    wire [NBITS_ACC-1:0] acc_rnd = (rnd && (shift_right_i != 0)) ? (acc_out + ({{(NBITS_ACC-1){1'b0}}, 1'b1} << (shift_right_i - 1))) :
                                                                    acc_out;

    wire [NBITS_ACC-1:0] acc_shr = (unsigned_mode) ? (acc_rnd  >> shift_right_i) :
                                                     (acc_rnd >>> shift_right_i);

    wire [NBITS_ACC-1:0] acc_sat_u = (acc_shr[NBITS_ACC-1:NBITS_Z] != 0) ? {{(NBITS_ACC-NBITS_Z){1'b0}},{NBITS_Z{1'b1}}} :
                                                                           {{(NBITS_ACC-NBITS_Z){1'b0}},{acc_shr[NBITS_Z-1:0]}};

    wire [NBITS_ACC-1:0] acc_sat_s = ((|acc_shr[NBITS_ACC-1:NBITS_Z-1] == 1'b0) ||
                                      (&acc_shr[NBITS_ACC-1:NBITS_Z-1] == 1'b1)) ? {{(NBITS_ACC-NBITS_Z){1'b0}},{acc_shr[NBITS_Z-1:0]}} :
                                                                                   {{(NBITS_ACC-NBITS_Z){1'b0}},{acc_shr[NBITS_ACC-1],{NBITS_Z-1{~acc_shr[NBITS_ACC-1]}}}};

    wire [NBITS_ACC-1:0] acc_sat = (sat) ? ((unsigned_mode) ? acc_sat_u : acc_sat_s) : acc_shr;

    // Output signals
    wire [NBITS_Z-1:0]  z0;
    reg  [NBITS_Z-1:0]  z1;
    wire [NBITS_Z-1:0]  z2;

    assign z0 = mult_xtnd[NBITS_Z-1:0];
    assign z2 = acc_sat[NBITS_Z-1:0];

    initial z1 <= 0;

    always @(posedge clock_i or posedge s_reset)
        if (s_reset)
            z1 <= 0;
        else begin
            z1 <= (output_select_i == 3'b100) ? z0 : z2;
        end

    // Output mux
    assign z_o = (output_select_i == 3'h0) ?   z0 :
                 (output_select_i == 3'h1) ?   z2 :
                 (output_select_i == 3'h2) ?   z2 :
                 (output_select_i == 3'h3) ?   z2 :
                 (output_select_i == 3'h4) ?   z1 :
                 (output_select_i == 3'h5) ?   z1 :
                 (output_select_i == 3'h6) ?   z1 :
                           z1;  // if output_select_i == 3'h7

    // B input delayed passthrough
    initial dly_b_o <= 0;

    always @(posedge clock_i or posedge s_reset)
        if (s_reset)
            dly_b_o <= 0;
        else
            dly_b_o <= b_i;

endmodule



// ---------------------------------------- //
// ----- DSP cells simulation modules ----- //
// ------ Control bits in parameters ------ //
// ---------------------------------------- //

module QL_DSP3 ( // TODO: Name subject to change
    input  wire [19:0] a,
    input  wire [17:0] b,
    input  wire [ 5:0] acc_fir,
    output wire [37:0] z,
    output wire [17:0] dly_b,

    (* clkbuf_sink *)
    input  wire       clk,
    input  wire       reset,

    input  wire [2:0] feedback,
    input  wire       load_acc,
    input  wire       unsigned_a,
    input  wire       unsigned_b,
    input  wire       subtract
);

    parameter [92:0] MODE_BITS = 93'b0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    localparam [0:0] F_MODE          = MODE_BITS[80];
    localparam [2:0] OUTPUT_SELECT   = MODE_BITS[83:81];
    localparam [0:0] SATURATE_ENABLE = MODE_BITS[84];
    localparam [5:0] SHIFT_RIGHT     = MODE_BITS[90:85];
    localparam [0:0] ROUND           = MODE_BITS[91];
    localparam [0:0] REGISTER_INPUTS = MODE_BITS[92];

    localparam NBITS_ACC = 64;
    localparam NBITS_A = 20;
    localparam NBITS_B = 18;
    localparam NBITS_Z = 38;

    // Fractured
    generate if(F_MODE == 1'b1) begin

        wire [(NBITS_Z/2)-1:0] dsp_frac0_z;
        wire [(NBITS_Z/2)-1:0] dsp_frac1_z;

        wire [(NBITS_B/2)-1:0] dsp_frac0_dly_b;
        wire [(NBITS_B/2)-1:0] dsp_frac1_dly_b;

        dsp_t1_sim_cfg_params #(
            .NBITS_A            (NBITS_A/2),
            .NBITS_B            (NBITS_B/2),
            .NBITS_ACC          (NBITS_ACC/2),
            .NBITS_Z            (NBITS_Z/2),
            .OUTPUT_SELECT      (OUTPUT_SELECT),
            .SATURATE_ENABLE    (SATURATE_ENABLE),
            .SHIFT_RIGHT        (SHIFT_RIGHT),
            .ROUND              (ROUND),
            .REGISTER_INPUTS    (REGISTER_INPUTS)
        ) dsp_frac0 (
            .a_i(a[(NBITS_A/2)-1:0]),
            .b_i(b[(NBITS_B/2)-1:0]),
            .z_o(dsp_frac0_z),
            .dly_b_o(dsp_frac0_dly_b),

            .acc_fir_i(acc_fir),
            .feedback_i(feedback),
            .load_acc_i(load_acc),

            .unsigned_a_i(unsigned_a),
            .unsigned_b_i(unsigned_b),

            .clock_i(clk),
            .s_reset(reset),

            .subtract_i(subtract),
            .coef_0_i(COEFF_0[(NBITS_A/2)-1:0]),
            .coef_1_i(COEFF_1[(NBITS_A/2)-1:0]),
            .coef_2_i(COEFF_2[(NBITS_A/2)-1:0]),
            .coef_3_i(COEFF_3[(NBITS_A/2)-1:0])
        );

        dsp_t1_sim_cfg_params #(
            .NBITS_A            (NBITS_A/2),
            .NBITS_B            (NBITS_B/2),
            .NBITS_ACC          (NBITS_ACC/2),
            .NBITS_Z            (NBITS_Z/2),
            .OUTPUT_SELECT      (OUTPUT_SELECT),
            .SATURATE_ENABLE    (SATURATE_ENABLE),
            .SHIFT_RIGHT        (SHIFT_RIGHT),
            .ROUND              (ROUND),
            .REGISTER_INPUTS    (REGISTER_INPUTS)
        ) dsp_frac1 (
            .a_i(a[NBITS_A-1:NBITS_A/2]),
            .b_i(b[NBITS_B-1:NBITS_B/2]),
            .z_o(dsp_frac1_z),
            .dly_b_o(dsp_frac1_dly_b),
            .acc_fir_i(acc_fir),
            .feedback_i(feedback),
            .load_acc_i(load_acc),

            .unsigned_a_i(unsigned_a),
            .unsigned_b_i(unsigned_b),

            .clock_i(clk),
            .s_reset(reset),

            .subtract_i(subtract),
            .coef_0_i(COEFF_0[NBITS_A-1:NBITS_A/2]),
            .coef_1_i(COEFF_1[NBITS_A-1:NBITS_A/2]),
            .coef_2_i(COEFF_2[NBITS_A-1:NBITS_A/2]),
            .coef_3_i(COEFF_3[NBITS_A-1:NBITS_A/2])
        );

        assign z = {dsp_frac1_z, dsp_frac0_z};
        assign dly_b = {dsp_frac1_dly_b, dsp_frac0_dly_b};

    // Whole
    end else begin

        dsp_t1_sim_cfg_params #(
            .NBITS_A            (NBITS_A),
            .NBITS_B            (NBITS_B),
            .NBITS_ACC          (NBITS_ACC),
            .NBITS_Z            (NBITS_Z),
            .OUTPUT_SELECT      (OUTPUT_SELECT),
            .SATURATE_ENABLE    (SATURATE_ENABLE),
            .SHIFT_RIGHT        (SHIFT_RIGHT),
            .ROUND              (ROUND),
            .REGISTER_INPUTS    (REGISTER_INPUTS)
        ) dsp_full (
            .a_i(a),
            .b_i(b),
            .z_o(z),
            .dly_b_o(dly_b),

            .acc_fir_i(acc_fir),
            .feedback_i(feedback),
            .load_acc_i(load_acc),

            .unsigned_a_i(unsigned_a),
            .unsigned_b_i(unsigned_b),

            .clock_i(clk),
            .s_reset(reset),

            .subtract_i(subtract),
            .coef_0_i(COEFF_0),
            .coef_1_i(COEFF_1),
            .coef_2_i(COEFF_2),
            .coef_3_i(COEFF_3)
        );

    end endgenerate

endmodule

module QL_DSP3_MULT ( // TODO: Name subject to change
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    input  wire       reset,

    input  wire [2:0] feedback,
    input  wire       unsigned_a,
    input  wire       unsigned_b
);

    parameter [92:0] MODE_BITS = 93'b0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    localparam [0:0] F_MODE          = MODE_BITS[80];
    localparam [2:0] OUTPUT_SELECT   = MODE_BITS[83:81];    // unregistered output: a * b (0)
    localparam [0:0] SATURATE_ENABLE = MODE_BITS[84];
    localparam [5:0] SHIFT_RIGHT     = MODE_BITS[90:85];
    localparam [0:0] ROUND           = MODE_BITS[91];
    localparam [0:0] REGISTER_INPUTS = MODE_BITS[92];       // unregistered inputs

    QL_DSP3 #(
        .MODE_BITS({
            REGISTER_INPUTS,
            ROUND,
            SHIFT_RIGHT,
            SATURATE_ENABLE,
            OUTPUT_SELECT,
            F_MODE,
            COEFF_3,
            COEFF_2,
            COEFF_1,
            COEFF_0
        })
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .reset(reset),

        .feedback(feedback),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b)
    );
endmodule

module QL_DSP3_MULT_REGIN ( // TODO: Name subject to change
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire       clk,
    input  wire       reset,

    input  wire [2:0] feedback,

    input  wire       unsigned_a,
    input  wire       unsigned_b
);

    wire [37:0] dly_b_o;
    parameter [92:0] MODE_BITS = 93'b0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    localparam [0:0] F_MODE          = MODE_BITS[80];
    localparam [2:0] OUTPUT_SELECT   = MODE_BITS[83:81];    // unregistered output: a * b (0)
    localparam [0:0] SATURATE_ENABLE = MODE_BITS[84];
    localparam [5:0] SHIFT_RIGHT     = MODE_BITS[90:85];
    localparam [0:0] ROUND           = MODE_BITS[91];
    localparam [0:0] REGISTER_INPUTS = MODE_BITS[92];       // registered inputs

    QL_DSP3 #(
        .MODE_BITS({
            REGISTER_INPUTS,
            ROUND,
            SHIFT_RIGHT,
            SATURATE_ENABLE,
            OUTPUT_SELECT,
            F_MODE,
            COEFF_3,
            COEFF_2,
            COEFF_1,
            COEFF_0
        })
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .feedback(feedback),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset)
    );
endmodule

module QL_DSP3_MULT_REGOUT ( // TODO: Name subject to change
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire       clk,
    input  wire       reset,

    input  wire [2:0] feedback,

    input  wire       unsigned_a,
    input  wire       unsigned_b
);

    parameter [92:0] MODE_BITS = 93'b0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    localparam [0:0] F_MODE          = MODE_BITS[80];
    localparam [2:0] OUTPUT_SELECT   = MODE_BITS[83:81];    // registered output: a * b (4)
    localparam [0:0] SATURATE_ENABLE = MODE_BITS[84];
    localparam [5:0] SHIFT_RIGHT     = MODE_BITS[90:85];
    localparam [0:0] ROUND           = MODE_BITS[91];
    localparam [0:0] REGISTER_INPUTS = MODE_BITS[92];       // unregistered inputs

    QL_DSP3 #(
        .MODE_BITS({
            REGISTER_INPUTS,
            ROUND,
            SHIFT_RIGHT,
            SATURATE_ENABLE,
            OUTPUT_SELECT,
            F_MODE,
            COEFF_3,
            COEFF_2,
            COEFF_1,
            COEFF_0
        })
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .feedback(feedback),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset)
    );
endmodule

module QL_DSP3_MULT_REGIN_REGOUT ( // TODO: Name subject to change
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire       clk,
    input  wire       reset,

    input  wire [2:0] feedback,

    input  wire       unsigned_a,
    input  wire       unsigned_b
);

    parameter [92:0] MODE_BITS = 93'b0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    localparam [0:0] F_MODE          = MODE_BITS[80];
    localparam [2:0] OUTPUT_SELECT   = MODE_BITS[83:81];    // registered output: a * b (4)
    localparam [0:0] SATURATE_ENABLE = MODE_BITS[84];
    localparam [5:0] SHIFT_RIGHT     = MODE_BITS[90:85];
    localparam [0:0] ROUND           = MODE_BITS[91];
    localparam [0:0] REGISTER_INPUTS = MODE_BITS[92];       // unregistered inputs

    QL_DSP3 #(
        .MODE_BITS({
            REGISTER_INPUTS,
            ROUND,
            SHIFT_RIGHT,
            SATURATE_ENABLE,
            OUTPUT_SELECT,
            F_MODE,
            COEFF_3,
            COEFF_2,
            COEFF_1,
            COEFF_0
        })
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .feedback(feedback),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset)
    );
endmodule

module QL_DSP3_MULTADD (
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    input  wire        reset,

    input  wire [ 2:0] feedback,
    input  wire [ 5:0] acc_fir,
    input  wire        load_acc,
    input  wire        unsigned_a,
    input  wire        unsigned_b,
    input  wire        subtract
);

    parameter [92:0] MODE_BITS = 93'b0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    localparam [0:0] F_MODE          = MODE_BITS[80];
    localparam [2:0] OUTPUT_SELECT   = MODE_BITS[83:81];
    localparam [0:0] SATURATE_ENABLE = MODE_BITS[84];
    localparam [5:0] SHIFT_RIGHT     = MODE_BITS[90:85];
    localparam [0:0] ROUND           = MODE_BITS[91];
    localparam [0:0] REGISTER_INPUTS = MODE_BITS[92];

    QL_DSP3 #(
        .MODE_BITS({
            REGISTER_INPUTS,
            ROUND,
            SHIFT_RIGHT,
            SATURATE_ENABLE,
            OUTPUT_SELECT,
            F_MODE,
            COEFF_3,
            COEFF_2,
            COEFF_1,
            COEFF_0
        })
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .feedback(feedback),
        .acc_fir(acc_fir),
        .load_acc(load_acc),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .reset(reset),
        .subtract(subtract)
    );
endmodule

module QL_DSP3_MULTADD_REGIN (
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire        clk,
    input  wire        reset,

    input  wire [ 2:0] feedback,
    input  wire [ 5:0] acc_fir,
    input  wire        load_acc,
    input  wire        unsigned_a,
    input  wire        unsigned_b,
    input  wire        subtract
);

    parameter [92:0] MODE_BITS = 93'b0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    localparam [0:0] F_MODE          = MODE_BITS[80];
    localparam [2:0] OUTPUT_SELECT   = MODE_BITS[83:81];
    localparam [0:0] SATURATE_ENABLE = MODE_BITS[84];
    localparam [5:0] SHIFT_RIGHT     = MODE_BITS[90:85];
    localparam [0:0] ROUND           = MODE_BITS[91];
    localparam [0:0] REGISTER_INPUTS = MODE_BITS[92];

    QL_DSP3 #(
        .MODE_BITS({
            REGISTER_INPUTS,
            ROUND,
            SHIFT_RIGHT,
            SATURATE_ENABLE,
            OUTPUT_SELECT,
            F_MODE,
            COEFF_3,
            COEFF_2,
            COEFF_1,
            COEFF_0
        })
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .feedback(feedback),
        .acc_fir(acc_fir),
        .load_acc(load_acc),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset),
        .subtract(subtract)
    );
endmodule

module QL_DSP3_MULTADD_REGOUT (
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire        clk,
    input  wire        reset,

    input  wire [ 2:0] feedback,
    input  wire [ 5:0] acc_fir,
    input  wire        load_acc,
    input  wire        unsigned_a,
    input  wire        unsigned_b,
    input  wire        subtract
);

    parameter [92:0] MODE_BITS = 93'b0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    localparam [0:0] F_MODE          = MODE_BITS[80];
    localparam [2:0] OUTPUT_SELECT   = MODE_BITS[83:81];
    localparam [0:0] SATURATE_ENABLE = MODE_BITS[84];
    localparam [5:0] SHIFT_RIGHT     = MODE_BITS[90:85];
    localparam [0:0] ROUND           = MODE_BITS[91];
    localparam [0:0] REGISTER_INPUTS = MODE_BITS[92];

    QL_DSP3 #(
        .MODE_BITS({
            REGISTER_INPUTS,
            ROUND,
            SHIFT_RIGHT,
            SATURATE_ENABLE,
            OUTPUT_SELECT,
            F_MODE,
            COEFF_3,
            COEFF_2,
            COEFF_1,
            COEFF_0
        })
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .feedback(feedback),
        .acc_fir(acc_fir),
        .load_acc(load_acc),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset),
        .subtract(subtract)
    );
endmodule

module QL_DSP3_MULTADD_REGIN_REGOUT (
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire        clk,
    input  wire        reset,

    input  wire [ 2:0] feedback,
    input  wire [ 5:0] acc_fir,
    input  wire        load_acc,
    input  wire        unsigned_a,
    input  wire        unsigned_b,
    input  wire        subtract
);

    parameter [92:0] MODE_BITS = 93'b0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    localparam [0:0] F_MODE          = MODE_BITS[80];
    localparam [2:0] OUTPUT_SELECT   = MODE_BITS[83:81];
    localparam [0:0] SATURATE_ENABLE = MODE_BITS[84];
    localparam [5:0] SHIFT_RIGHT     = MODE_BITS[90:85];
    localparam [0:0] ROUND           = MODE_BITS[91];
    localparam [0:0] REGISTER_INPUTS = MODE_BITS[92];

    QL_DSP3 #(
        .MODE_BITS({
            REGISTER_INPUTS,
            ROUND,
            SHIFT_RIGHT,
            SATURATE_ENABLE,
            OUTPUT_SELECT,
            F_MODE,
            COEFF_3,
            COEFF_2,
            COEFF_1,
            COEFF_0
        })
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .feedback(feedback),
        .acc_fir(acc_fir),
        .load_acc(load_acc),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset),
        .subtract(subtract)
    );
endmodule

module QL_DSP3_MULTACC (
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire        clk,
    input  wire        reset,

    input  wire [ 2:0] feedback,
    input  wire        load_acc,
    input  wire        unsigned_a,
    input  wire        unsigned_b,
    input  wire        subtract
);

    parameter [92:0] MODE_BITS = 93'b0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    localparam [0:0] F_MODE          = MODE_BITS[80];
    localparam [2:0] OUTPUT_SELECT   = MODE_BITS[83:81];
    localparam [0:0] SATURATE_ENABLE = MODE_BITS[84];
    localparam [5:0] SHIFT_RIGHT     = MODE_BITS[90:85];
    localparam [0:0] ROUND           = MODE_BITS[91];
    localparam [0:0] REGISTER_INPUTS = MODE_BITS[92];

    QL_DSP3 #(
        .MODE_BITS({
            REGISTER_INPUTS,
            ROUND,
            SHIFT_RIGHT,
            SATURATE_ENABLE,
            OUTPUT_SELECT,
            F_MODE,
            COEFF_3,
            COEFF_2,
            COEFF_1,
            COEFF_0
        })
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .feedback(feedback),
        .load_acc(load_acc),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset),
        .subtract(subtract)
    );
endmodule

module QL_DSP3_MULTACC_REGIN (
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire        clk,
    input  wire        reset,

    input  wire [ 2:0] feedback,
    input  wire        load_acc,
    input  wire        unsigned_a,
    input  wire        unsigned_b,
    input  wire        subtract
);

    parameter [92:0] MODE_BITS = 93'b0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    localparam [0:0] F_MODE          = MODE_BITS[80];
    localparam [2:0] OUTPUT_SELECT   = MODE_BITS[83:81];
    localparam [0:0] SATURATE_ENABLE = MODE_BITS[84];
    localparam [5:0] SHIFT_RIGHT     = MODE_BITS[90:85];
    localparam [0:0] ROUND           = MODE_BITS[91];
    localparam [0:0] REGISTER_INPUTS = MODE_BITS[92];

    QL_DSP3 #(
        .MODE_BITS({
            REGISTER_INPUTS,
            ROUND,
            SHIFT_RIGHT,
            SATURATE_ENABLE,
            OUTPUT_SELECT,
            F_MODE,
            COEFF_3,
            COEFF_2,
            COEFF_1,
            COEFF_0
        })
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .feedback(feedback),
        .load_acc(load_acc),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset),
        .subtract(subtract)
    );
endmodule

module QL_DSP3_MULTACC_REGOUT (
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire        clk,
    input  wire        reset,

    input  wire [ 2:0] feedback,
    input  wire        load_acc,
    input  wire        unsigned_a,
    input  wire        unsigned_b,
    input  wire        subtract
);

    parameter [92:0] MODE_BITS = 93'b0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    localparam [0:0] F_MODE          = MODE_BITS[80];
    localparam [2:0] OUTPUT_SELECT   = MODE_BITS[83:81];
    localparam [0:0] SATURATE_ENABLE = MODE_BITS[84];
    localparam [5:0] SHIFT_RIGHT     = MODE_BITS[90:85];
    localparam [0:0] ROUND           = MODE_BITS[91];
    localparam [0:0] REGISTER_INPUTS = MODE_BITS[92];

    QL_DSP3 #(
        .MODE_BITS({
            REGISTER_INPUTS,
            ROUND,
            SHIFT_RIGHT,
            SATURATE_ENABLE,
            OUTPUT_SELECT,
            F_MODE,
            COEFF_3,
            COEFF_2,
            COEFF_1,
            COEFF_0
        })
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .feedback(feedback),
        .load_acc(load_acc),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset),
        .subtract(subtract)
    );
endmodule

module QL_DSP3_MULTACC_REGIN_REGOUT (
    input  wire [19:0] a,
    input  wire [17:0] b,
    output wire [37:0] z,

    (* clkbuf_sink *)
    input  wire        clk,
    input  wire        reset,

    input  wire [ 2:0] feedback,
    input  wire        load_acc,
    input  wire        unsigned_a,
    input  wire        unsigned_b,
    input  wire        subtract
);

    parameter [92:0] MODE_BITS = 93'b0;

    localparam [19:0] COEFF_0 = MODE_BITS[19:0];
    localparam [19:0] COEFF_1 = MODE_BITS[39:20];
    localparam [19:0] COEFF_2 = MODE_BITS[59:40];
    localparam [19:0] COEFF_3 = MODE_BITS[79:60];

    localparam [0:0] F_MODE          = MODE_BITS[80];
    localparam [2:0] OUTPUT_SELECT   = MODE_BITS[83:81];
    localparam [0:0] SATURATE_ENABLE = MODE_BITS[84];
    localparam [5:0] SHIFT_RIGHT     = MODE_BITS[90:85];
    localparam [0:0] ROUND           = MODE_BITS[91];
    localparam [0:0] REGISTER_INPUTS = MODE_BITS[92];

    QL_DSP3 #(
        .MODE_BITS({
            REGISTER_INPUTS,
            ROUND,
            SHIFT_RIGHT,
            SATURATE_ENABLE,
            OUTPUT_SELECT,
            F_MODE,
            COEFF_3,
            COEFF_2,
            COEFF_1,
            COEFF_0
        })
    ) dsp (
        .a(a),
        .b(b),
        .z(z),

        .feedback(feedback),
        .load_acc(load_acc),

        .unsigned_a(unsigned_a),
        .unsigned_b(unsigned_b),

        .clk(clk),
        .reset(reset),
        .subtract(subtract)
    );
endmodule

module dsp_t1_20x18x64_cfg_params (
    input  wire [19:0] a_i,
    input  wire [17:0] b_i,
    input  wire [ 5:0] acc_fir_i,
    output wire [37:0] z_o,
    output wire [17:0] dly_b_o,

    (* clkbuf_sink *)
    input  wire        clock_i,
    input  wire        reset_i,

    input  wire [ 2:0] feedback_i,
    input  wire        load_acc_i,
    input  wire        unsigned_a_i,
    input  wire        unsigned_b_i,
    input  wire        subtract_i
);

    parameter [19:0] COEFF_0 = 20'b0;
    parameter [19:0] COEFF_1 = 20'b0;
    parameter [19:0] COEFF_2 = 20'b0;
    parameter [19:0] COEFF_3 = 20'b0;

    parameter [2:0] OUTPUT_SELECT   = 3'b0;
    parameter [0:0] SATURATE_ENABLE = 1'b0;
    parameter [5:0] SHIFT_RIGHT     = 6'b0;
    parameter [0:0] ROUND           = 1'b0;
    parameter [0:0] REGISTER_INPUTS = 1'b0;

    QL_DSP3 #(
        .MODE_BITS ({
            REGISTER_INPUTS,
            ROUND,
            SHIFT_RIGHT,
            SATURATE_ENABLE,
            OUTPUT_SELECT,
            1'b0, // Not fractured
            COEFF_3,
            COEFF_2,
            COEFF_1,
            COEFF_0
        })
    ) dsp (
        .a(a_i),
        .b(b_i),
        .z(z_o),
        .dly_b(dly_b_o),

        .acc_fir(acc_fir_i),
        .feedback(feedback_i),
        .load_acc(load_acc_i),

        .unsigned_a(unsigned_a_i),
        .unsigned_b(unsigned_b_i),

        .clk(clock_i),
        .reset(reset_i),
        .subtract(subtract_i)
    );
endmodule

module dsp_t1_10x9x32_cfg_params (
    input  wire [ 9:0] a_i,
    input  wire [ 8:0] b_i,
    input  wire [ 5:0] acc_fir_i,
    output wire [18:0] z_o,
    output wire [ 8:0] dly_b_o,

    (* clkbuf_sink *)
    input  wire        clock_i,
    input  wire        reset_i,

    input  wire [ 2:0] feedback_i,
    input  wire        load_acc_i,
    input  wire        unsigned_a_i,
    input  wire        unsigned_b_i,
    input  wire        subtract_i
);

    parameter [9:0] COEFF_0 = 10'b0;
    parameter [9:0] COEFF_1 = 10'b0;
    parameter [9:0] COEFF_2 = 10'b0;
    parameter [9:0] COEFF_3 = 10'b0;

    parameter [2:0] OUTPUT_SELECT   = 3'b0;
    parameter [0:0] SATURATE_ENABLE = 1'b0;
    parameter [5:0] SHIFT_RIGHT     = 6'b0;
    parameter [0:0] ROUND           = 1'b0;
    parameter [0:0] REGISTER_INPUTS = 1'b0;

    wire [18:0] z_rem;
    wire [8:0] dly_b_rem;

    QL_DSP3 #(
        .MODE_BITS ({
            REGISTER_INPUTS,
            ROUND,
            SHIFT_RIGHT,
            SATURATE_ENABLE,
            OUTPUT_SELECT,
            1'b1, // Fractured
            10'd0, COEFF_3,
            10'd0, COEFF_2,
            10'd0, COEFF_1,
            10'd0, COEFF_0
        })
    ) dsp (
        .a({10'b0, a_i}),
        .b({9'b0, b_i}),
        .z({z_rem, z_o}),
        .dly_b({dly_b_rem, dly_b_o}),

        .acc_fir(acc_fir_i),
        .feedback(feedback_i),
        .load_acc(load_acc_i),

        .unsigned_a(unsigned_a_i),
        .unsigned_b(unsigned_b_i),

        .clk(clock_i),
        .reset(reset_i),
        .subtract(subtract_i)
    );
endmodule

module dsp_t1_sim_cfg_params # (
    parameter NBITS_ACC  = 64,
    parameter NBITS_A    = 20,
    parameter NBITS_B    = 18,
    parameter NBITS_Z    = 38,

    parameter [2:0] OUTPUT_SELECT   = 3'b0,
    parameter [0:0] SATURATE_ENABLE = 1'b0,
    parameter [5:0] SHIFT_RIGHT     = 6'b0,
    parameter [0:0] ROUND           = 1'b0,
    parameter [0:0] REGISTER_INPUTS = 1'b0
)(
    input  wire [NBITS_A-1:0] a_i,
    input  wire [NBITS_B-1:0] b_i,
    output wire [NBITS_Z-1:0] z_o,
    output reg  [NBITS_B-1:0] dly_b_o,

    input  wire [5:0]         acc_fir_i,
    input  wire [2:0]         feedback_i,
    input  wire               load_acc_i,

    input  wire               unsigned_a_i,
    input  wire               unsigned_b_i,

    input  wire               clock_i,
    input  wire               s_reset,

    input  wire               subtract_i,
    input  wire [NBITS_A-1:0] coef_0_i,
    input  wire [NBITS_A-1:0] coef_1_i,
    input  wire [NBITS_A-1:0] coef_2_i,
    input  wire [NBITS_A-1:0] coef_3_i
);

// FIXME: The version of Icarus Verilog from Conda seems not to recognize the
// $error macro. Disable this sanity check for now because of that.
`ifndef __ICARUS__
    if (NBITS_ACC < NBITS_A + NBITS_B)
        $error("NBITS_ACC must be > NBITS_A + NBITS_B");
`endif

    // Input registers
    reg  [NBITS_A-1:0]  r_a;
    reg  [NBITS_B-1:0]  r_b;
    reg  [5:0]          r_acc_fir;
    reg                 r_unsigned_a;
    reg                 r_unsigned_b;
    reg                 r_load_acc;
    reg  [2:0]          r_feedback;
    reg  [5:0]          r_shift_d1;
    reg  [5:0]          r_shift_d2;
    reg         r_subtract;
    reg         r_sat;
    reg         r_rnd;
    reg [NBITS_ACC-1:0] acc;

    initial begin
        r_a          <= 0;
        r_b          <= 0;

        r_acc_fir    <= 0;
        r_unsigned_a <= 0;
        r_unsigned_b <= 0;
        r_feedback   <= 0;
        r_shift_d1   <= 0;
        r_shift_d2   <= 0;
        r_subtract   <= 0;
        r_load_acc   <= 0;
        r_sat        <= 0;
        r_rnd        <= 0;
    end

    always @(posedge clock_i or posedge s_reset) begin
        if (s_reset) begin

            r_a <= 'h0;
            r_b <= 'h0;

            r_acc_fir    <= 0;
            r_unsigned_a <= 0;
            r_unsigned_b <= 0;
            r_feedback   <= 0;
            r_shift_d1   <= 0;
            r_shift_d2   <= 0;
            r_subtract   <= 0;
            r_load_acc   <= 0;
            r_sat    <= 0;
            r_rnd    <= 0;

        end else begin

            r_a <= a_i;
            r_b <= b_i;

            r_acc_fir    <= acc_fir_i;
            r_unsigned_a <= unsigned_a_i;
            r_unsigned_b <= unsigned_b_i;
            r_feedback   <= feedback_i;
            r_shift_d1   <= SHIFT_RIGHT;
            r_shift_d2   <= r_shift_d1;
            r_subtract   <= subtract_i;
            r_load_acc   <= load_acc_i;
            r_sat    <= r_sat;
            r_rnd    <= r_rnd;

        end
    end

    // Registered / non-registered input path select
    wire [NBITS_A-1:0]  a = REGISTER_INPUTS ? r_a : a_i;
    wire [NBITS_B-1:0]  b = REGISTER_INPUTS ? r_b : b_i;

    wire [5:0] acc_fir = REGISTER_INPUTS ? r_acc_fir : acc_fir_i;
    wire       unsigned_a = REGISTER_INPUTS ? r_unsigned_a : unsigned_a_i;
    wire       unsigned_b = REGISTER_INPUTS ? r_unsigned_b : unsigned_b_i;
    wire [2:0] feedback   = REGISTER_INPUTS ? r_feedback   : feedback_i;
    wire       load_acc   = REGISTER_INPUTS ? r_load_acc   : load_acc_i;
    wire       subtract   = REGISTER_INPUTS ? r_subtract   : subtract_i;
    wire       sat    = REGISTER_INPUTS ? r_sat : SATURATE_ENABLE;
    wire       rnd    = REGISTER_INPUTS ? r_rnd : ROUND;

    // Shift right control
    wire [5:0] shift_d1 = REGISTER_INPUTS ? r_shift_d1 : SHIFT_RIGHT;
    wire [5:0] shift_d2 = OUTPUT_SELECT[1] ? shift_d1 : r_shift_d2;

    // Multiplier
    wire unsigned_mode = unsigned_a & unsigned_b;
    wire [NBITS_A-1:0] mult_a;
    assign mult_a = (feedback == 3'h0) ?   a :
                    (feedback == 3'h1) ?   a :
                    (feedback == 3'h2) ?   a :
                    (feedback == 3'h3) ?   acc[NBITS_A-1:0] :
                    (feedback == 3'h4) ?   coef_0_i :
                    (feedback == 3'h5) ?   coef_1_i :
                    (feedback == 3'h6) ?   coef_2_i :
                       coef_3_i;    // if feedback == 3'h7

    wire [NBITS_B-1:0] mult_b = (feedback == 2'h2) ? {NBITS_B{1'b0}}  : b;

    wire [NBITS_A-1:0] mult_sgn_a = mult_a[NBITS_A-1];
    wire [NBITS_A-1:0] mult_mag_a = (mult_sgn_a && !unsigned_a) ? (~mult_a + 1) : mult_a;
    wire [NBITS_B-1:0] mult_sgn_b = mult_b[NBITS_B-1];
    wire [NBITS_B-1:0] mult_mag_b = (mult_sgn_b && !unsigned_b) ? (~mult_b + 1) : mult_b;

    wire [NBITS_A+NBITS_B-1:0] mult_mag = mult_mag_a * mult_mag_b;
    wire mult_sgn = (mult_sgn_a && !unsigned_a) ^ (mult_sgn_b && !unsigned_b);

    wire [NBITS_A+NBITS_B-1:0] mult = (unsigned_a && unsigned_b) ?
        (mult_a * mult_b) : (mult_sgn ? (~mult_mag + 1) : mult_mag);

    // Sign extension
    wire [NBITS_ACC-1:0] mult_xtnd = unsigned_mode ?
        {{(NBITS_ACC-NBITS_A-NBITS_B){1'b0}},                    mult[NBITS_A+NBITS_B-1:0]} :
        {{(NBITS_ACC-NBITS_A-NBITS_B){mult[NBITS_A+NBITS_B-1]}}, mult[NBITS_A+NBITS_B-1:0]};

    // Adder
    wire [NBITS_ACC-1:0] acc_fir_int = unsigned_a ? {{(NBITS_ACC-NBITS_A){1'b0}},         a} :
                                                    {{(NBITS_ACC-NBITS_A){a[NBITS_A-1]}}, a} ;

    wire [NBITS_ACC-1:0] add_a = (subtract) ? (~mult_xtnd + 1) : mult_xtnd;
    wire [NBITS_ACC-1:0] add_b = (feedback_i == 3'h0) ? acc :
                                 (feedback_i == 3'h1) ? {{NBITS_ACC}{1'b0}} : (acc_fir_int << acc_fir);

    wire [NBITS_ACC-1:0] add_o = add_a + add_b;

    // Accumulator
    initial acc <= 0;

    always @(posedge clock_i or posedge s_reset)
        if (s_reset) acc <= 'h0;
        else begin
            if (load_acc)
                acc <= add_o;
            else
                acc <= acc;
        end

    // Adder/accumulator output selection
    wire [NBITS_ACC-1:0] acc_out = (OUTPUT_SELECT[1]) ? add_o : acc;

    // Round, shift, saturate
    wire [NBITS_ACC-1:0] acc_rnd = (rnd && (SHIFT_RIGHT != 0)) ? (acc_out + ({{(NBITS_ACC-1){1'b0}}, 1'b1} << (SHIFT_RIGHT - 1))) :
                                                                    acc_out;

    wire [NBITS_ACC-1:0] acc_shr = (unsigned_mode) ? (acc_rnd  >> SHIFT_RIGHT) :
                                                     (acc_rnd >>> SHIFT_RIGHT);

    wire [NBITS_ACC-1:0] acc_sat_u = (acc_shr[NBITS_ACC-1:NBITS_Z] != 0) ? {{(NBITS_ACC-NBITS_Z){1'b0}},{NBITS_Z{1'b1}}} :
                                                                           {{(NBITS_ACC-NBITS_Z){1'b0}},{acc_shr[NBITS_Z-1:0]}};

    wire [NBITS_ACC-1:0] acc_sat_s = ((|acc_shr[NBITS_ACC-1:NBITS_Z-1] == 1'b0) ||
                                      (&acc_shr[NBITS_ACC-1:NBITS_Z-1] == 1'b1)) ? {{(NBITS_ACC-NBITS_Z){1'b0}},{acc_shr[NBITS_Z-1:0]}} :
                                                                                   {{(NBITS_ACC-NBITS_Z){1'b0}},{acc_shr[NBITS_ACC-1],{NBITS_Z-1{~acc_shr[NBITS_ACC-1]}}}};

    wire [NBITS_ACC-1:0] acc_sat = (sat) ? ((unsigned_mode) ? acc_sat_u : acc_sat_s) : acc_shr;

    // Output signals
    wire [NBITS_Z-1:0]  z0;
    reg  [NBITS_Z-1:0]  z1;
    wire [NBITS_Z-1:0]  z2;

    assign z0 = mult_xtnd[NBITS_Z-1:0];
    assign z2 = acc_sat[NBITS_Z-1:0];

    initial z1 <= 0;

    always @(posedge clock_i or posedge s_reset)
        if (s_reset)
            z1 <= 0;
        else begin
            z1 <= (OUTPUT_SELECT == 3'b100) ? z0 : z2;
        end

    // Output mux
    assign z_o = (OUTPUT_SELECT == 3'h0) ?   z0 :
                 (OUTPUT_SELECT == 3'h1) ?   z2 :
                 (OUTPUT_SELECT == 3'h2) ?   z2 :
                 (OUTPUT_SELECT == 3'h3) ?   z2 :
                 (OUTPUT_SELECT == 3'h4) ?   z1 :
                 (OUTPUT_SELECT == 3'h5) ?   z1 :
                 (OUTPUT_SELECT == 3'h6) ?   z1 :
                           z1;  // if OUTPUT_SELECT == 3'h7

    // B input delayed passthrough
    initial dly_b_o <= 0;

    always @(posedge clock_i or posedge s_reset)
        if (s_reset)
            dly_b_o <= 0;
        else
            dly_b_o <= b_i;

endmodule
