// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module \$__QL_MUL20X18 (input [19:0] A, input [17:0] B, output [37:0] Y);
    parameter A_SIGNED = 0;
    parameter B_SIGNED = 0;
    parameter A_WIDTH = 0;
    parameter B_WIDTH = 0;
    parameter Y_WIDTH = 0;

    wire [19:0] a;
    wire [17:0] b;
    wire [63:0] z;

    assign a = (A_WIDTH == 20) ? A :
               (A_SIGNED) ? {{(20 - A_WIDTH){A[A_WIDTH-1]}}, A} :
                            {{(20 - A_WIDTH){1'b0}},         A};

    assign b = (B_WIDTH == 18) ? B :
               (B_SIGNED) ? {{(18 - B_WIDTH){B[B_WIDTH-1]}}, B} :
                            {{(18 - B_WIDTH){1'b0}},         B};

    dsp_t1_20x18x64 _TECHMAP_REPLACE_ (
        .a_i    (a),
        .b_i    (b),
        .z_o    (z),

        .register_inputs_i  (1'b0),
        .subtraction_mode_i (1'b0),
        .feedback_i         (2'b00),
        .round_i            (1'b0),
        .shift_right_i      (1'b0),
        .saturate_enable_i  (1'b0),
        .output_select_i    (1'b0)
    );

    assign Y = z[37:0];

endmodule

module \$__QL_MUL10X9 (input [9:0] A, input [8:0] B, output [18:0] Y);
    parameter A_SIGNED = 0;
    parameter B_SIGNED = 0;
    parameter A_WIDTH = 0;
    parameter B_WIDTH = 0;
    parameter Y_WIDTH = 0;

    wire [ 9:0] a;
    wire [ 8:0] b;
    wire [31:0] z;

    assign a = (A_WIDTH == 10) ? A :
               (A_SIGNED) ? {{(10 - A_WIDTH){A[A_WIDTH-1]}}, A} :
                            {{(10 - A_WIDTH){1'b0}},         A};

    assign b = (B_WIDTH ==  9) ? B :
               (B_SIGNED) ? {{( 9 - B_WIDTH){B[B_WIDTH-1]}}, B} :
                            {{( 9 - B_WIDTH){1'b0}},         B};

    dsp_t1_10x9x32 _TECHMAP_REPLACE_ (
        .a_i    (a),
        .b_i    (b),
        .z_o    (z),

        .register_inputs_i  (1'b0),
        .subtraction_mode_i (1'b0),
        .feedback_i         (2'b00),
        .round_i            (1'b0),
        .shift_right_i      (1'b0),
        .saturate_enable_i  (1'b0),
        .output_select_i    (1'b0)
    );

    assign Y = z[18:0];

endmodule

