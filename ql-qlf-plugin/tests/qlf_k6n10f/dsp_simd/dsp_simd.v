// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module simd_mult (
    input  wire         clk,
                
    input  wire [ 7:0]  a0,
    input  wire [ 7:0]  b0,
    output wire [15:0]  z0,
                
    input  wire [ 7:0]  a1,
    input  wire [ 7:0]  b1,
    output wire [15:0]  z1
);

    dsp_t1_10x9x32 dsp_0 (
        .a_i    (a0),
        .b_i    (b0),
        .z_o    (z0),

        .clock_i            (clk),

        .feedback_i         (3'd0),
        .load_acc_i         (1'b0),
        .unsigned_a_i       (1'b1),
        .unsigned_b_i       (1'b1),

        .output_select_i    (3'd0),
        .saturate_enable_i  (1'b0),
        .shift_right_i      (6'd0),
        .round_i            (1'b0),
        .subtract_i         (1'b0),
        .register_inputs_i  (1'b1)
    );    

    dsp_t1_10x9x32 dsp_1 (
        .a_i    (a1),
        .b_i    (b1),
        .z_o    (z1),

        .clock_i            (clk),

        .feedback_i         (3'd0),
        .load_acc_i         (1'b0),
        .unsigned_a_i       (1'b1),
        .unsigned_b_i       (1'b1),

        .output_select_i    (3'd0),
        .saturate_enable_i  (1'b0),
        .shift_right_i      (6'd0),
        .round_i            (1'b0),
        .subtract_i         (1'b0),
        .register_inputs_i  (1'b1)
    );    

endmodule

module simd_mult_inferred (
    input  wire         clk,
                
    input  wire [ 7:0]  a0,
    input  wire [ 7:0]  b0,
    output reg  [15:0]  z0,
                
    input  wire [ 7:0]  a1,
    input  wire [ 7:0]  b1,
    output reg  [15:0]  z1
);

    always @(posedge clk)
        z0 <= a0 * b0;

    always @(posedge clk)
        z1 <= a1 * b1;

endmodule

module simd_mult_odd (
    input  wire         clk,
                
    input  wire [ 7:0]  a0,
    input  wire [ 7:0]  b0,
    output wire [15:0]  z0,
                
    input  wire [ 7:0]  a1,
    input  wire [ 7:0]  b1,
    output wire [15:0]  z1,

    input  wire [ 7:0]  a2,
    input  wire [ 7:0]  b2,
    output wire [15:0]  z2
);

    dsp_t1_10x9x32 dsp_0 (
        .a_i    (a0),
        .b_i    (b0),
        .z_o    (z0),

        .clock_i            (clk),

        .feedback_i         (3'd0),
        .load_acc_i         (1'b0),
        .unsigned_a_i       (1'b1),
        .unsigned_b_i       (1'b1),

        .output_select_i    (3'd0),
        .saturate_enable_i  (1'b0),
        .shift_right_i      (6'd0),
        .round_i            (1'b0),
        .subtract_i         (1'b0),
        .register_inputs_i  (1'b1)
    );    

    dsp_t1_10x9x32 dsp_1 (
        .a_i    (a1),
        .b_i    (b1),
        .z_o    (z1),

        .clock_i            (clk),

        .feedback_i         (3'd0),
        .load_acc_i         (1'b0),
        .unsigned_a_i       (1'b1),
        .unsigned_b_i       (1'b1),

        .output_select_i    (3'd0),
        .saturate_enable_i  (1'b0),
        .shift_right_i      (6'd0),
        .round_i            (1'b0),
        .subtract_i         (1'b0),
        .register_inputs_i  (1'b1)
    );    

    dsp_t1_10x9x32 dsp_2 (
        .a_i    (a2),
        .b_i    (b2),
        .z_o    (z2),

        .clock_i            (clk),

        .feedback_i         (3'd0),
        .load_acc_i         (1'b0),
        .unsigned_a_i       (1'b1),
        .unsigned_b_i       (1'b1),

        .output_select_i    (3'd0),
        .saturate_enable_i  (1'b0),
        .shift_right_i      (6'd0),
        .round_i            (1'b0),
        .subtract_i         (1'b0),
        .register_inputs_i  (1'b1)
    );    

endmodule

module simd_mult_conflict (
    input  wire         clk0,
    input  wire         clk1,
                
    input  wire [ 7:0]  a0,
    input  wire [ 7:0]  b0,
    output wire [15:0]  z0,
                
    input  wire [ 7:0]  a1,
    input  wire [ 7:0]  b1,
    output wire [15:0]  z1
);

    dsp_t1_10x9x32 dsp_0 (
        .a_i    (a0),
        .b_i    (b0),
        .z_o    (z0),

        .clock_i            (clk0),

        .feedback_i         (3'd0),
        .load_acc_i         (1'b0),
        .unsigned_a_i       (1'b1),
        .unsigned_b_i       (1'b1),

        .output_select_i    (3'd0),
        .saturate_enable_i  (1'b0),
        .shift_right_i      (6'd0),
        .round_i            (1'b0),
        .subtract_i         (1'b0),
        .register_inputs_i  (1'b1)
    );    

    dsp_t1_10x9x32 dsp_1 (
        .a_i    (a1),
        .b_i    (b1),
        .z_o    (z1),

        .clock_i            (clk1),

        .feedback_i         (3'd0),
        .load_acc_i         (1'b0),
        .unsigned_a_i       (1'b1),
        .unsigned_b_i       (1'b1),

        .output_select_i    (3'd0),
        .saturate_enable_i  (1'b0),
        .shift_right_i      (6'd0),
        .round_i            (1'b0),
        .subtract_i         (1'b0),
        .register_inputs_i  (1'b1)
    );    

endmodule

