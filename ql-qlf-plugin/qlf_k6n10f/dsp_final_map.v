// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module dsp_t1_20x18x64 (
    input  [19:0] a_i,
    input  [17:0] b_i,
    input  [ 3:0] acc_fir_i,
    output [37:0] z_o,
    output [17:0] dly_b_o,

    input         clock_i,
    input         reset_i,

    input  [1:0]  feedback_i,
    input         load_acc_i,
    input         unsigned_a_i,
    input         unsigned_b_i,

    input  [2:0]  output_select_i,
    input         saturate_enable_i,
    input  [5:0]  shift_right_i,
    input         round_i,
    input         subtract_i,
    input         register_inputs_i,
    input  [19:0] coeff_0_i,
    input  [19:0] coeff_1_i,
    input  [19:0] coeff_2_i,
    input  [19:0] coeff_3_i
);

    QL_DSP2 _TECHMAP_REPLACE_ (
        .a                  (a_i),
        .b                  (b_i),
        .acc_fir            (acc_fir_i),
        .z                  (z_o),
        .dly_b              (dly_b_o),

        .clk                (clk_i),
        .reset              (reset_i),

        .feedback           (feedback_i),
        .load_acc           (load_acc_i),
        .unsigned_a         (unsigned_a_i),
        .unsigned_b         (unsigned_b_i),

        .f_mode             (1'b0), // No fracturation
        .output_select      (output_select_i),
        .saturate_enable    (saturate_enable_i),
        .shift_right        (shift_right_i),
        .round              (round_i),
        .subtract           (subtract_i),
        .register_inputs    (register_inputs_i),
        .coeff_0            (coeff_0_i),
        .coeff_1            (coeff_1_i),
        .coeff_2            (coeff_2_i),
        .coeff_3            (coeff_3_i)
    );

endmodule

module dsp_t1_10x9x32 (
    input  [ 9:0] a_i,
    input  [ 8:0] b_i,
    input  [ 1:0] acc_fir_i,
    output [18:0] z_o,
    output [ 8:0] dly_b_o,

    (* clkbuf_sink *)
    input         clock_i,
    input         reset_i,

    input  [1:0]  feedback_i,
    input         load_acc_i,
    input         unsigned_a_i,
    input         unsigned_b_i,

    input  [2:0]  output_select_i,
    input         saturate_enable_i,
    input  [5:0]  shift_right_i,
    input         round_i,
    input         subtract_i,
    input         register_inputs_i,
    input  [ 9:0] coeff_0_i,
    input  [ 9:0] coeff_1_i,
    input  [ 9:0] coeff_2_i,
    input  [ 9:0] coeff_3_i
);

    wire [37:0] z;
    wire [17:0] dly_b;

    QL_DSP2 _TECHMAP_REPLACE_ (
        .a                  ({10'd0, a_i}),
        .b                  ({ 9'd0, b_i}),
        .acc_fir            (acc_fir_i),
        .z                  (z),
        .dly_b              (dly_b),

        .clk                (clk_i),
        .reset              (reset_i),

        .feedback           (feedback_i),
        .load_acc           (load_acc_i),
        .unsigned_a         (unsigned_a_i),
        .unsigned_b         (unsigned_b_i),

        .f_mode             (1'b1), // Enable fractuation, Use the lower half
        .output_select      (output_select_i),
        .saturate_enable    (saturate_enable_i),
        .shift_right        (shift_right_i),
        .round              (round_i),
        .subtract           (subtract_i),
        .register_inputs    (register_inputs_i),
        .coeff_0            ({10'd0, coeff_0_i}),
        .coeff_1            ({10'd0, coeff_1_i}),
        .coeff_2            ({10'd0, coeff_2_i}),
        .coeff_3            ({10'd0, coeff_3_i})
    );

    assign z_o = z[18:0];
    assign dly_b_o = dly_b_o[8:0];

endmodule

