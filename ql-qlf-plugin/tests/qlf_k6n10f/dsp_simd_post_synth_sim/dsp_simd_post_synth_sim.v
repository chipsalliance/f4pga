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

module simd_mult (
    input  wire         clk,

    input  wire [ 9:0]  a0,
    input  wire [ 8:0]  b0,
    output reg  [18:0]  z0,

    input  wire [ 9:0]  a1,
    input  wire [ 8:0]  b1,
    output reg  [18:0]  z1
);

    always @(posedge clk)
        z0 <= a0 * b0;

    always @(posedge clk)
        z1 <= a1 * b1;

endmodule

module simd_mult_explicit_ports (
    input  wire         clk,

    input  wire [ 9:0]  a0,
    input  wire [ 9:0]  b0,
    output wire [18:0]  z0,

    input  wire [ 9:0]  a1,
    input  wire [ 9:0]  b1,
    output wire [18:0]  z1
);

    dsp_t1_10x9x32_cfg_ports dsp_0 (
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

    dsp_t1_10x9x32_cfg_ports dsp_1 (
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

module simd_mult_explicit_params (
    input  wire         clk,

    input  wire [ 9:0]  a0,
    input  wire [ 9:0]  b0,
    output wire [18:0]  z0,

    input  wire [ 9:0]  a1,
    input  wire [ 9:0]  b1,
    output wire [18:0]  z1
);

    dsp_t1_10x9x32_cfg_params #(
        .OUTPUT_SELECT      (3'd0),
        .SATURATE_ENABLE    (1'b0),
        .SHIFT_RIGHT        (6'd0),
        .ROUND              (1'b0),
        .REGISTER_INPUTS    (1'b1)
    ) dsp_0 (
        .a_i    (a0),
        .b_i    (b0),
        .z_o    (z0),

        .clock_i            (clk),

        .feedback_i         (3'd0),
        .load_acc_i         (1'b0),
        .unsigned_a_i       (1'b1),
        .unsigned_b_i       (1'b1),

        .subtract_i         (1'b0)
    );

    dsp_t1_10x9x32_cfg_params #(
        .OUTPUT_SELECT      (3'd0),
        .SATURATE_ENABLE    (1'b0),
        .SHIFT_RIGHT        (6'd0),
        .ROUND              (1'b0),
        .REGISTER_INPUTS    (1'b1)
    ) dsp_1 (
        .a_i    (a1),
        .b_i    (b1),
        .z_o    (z1),

        .clock_i            (clk),

        .feedback_i         (3'd0),
        .load_acc_i         (1'b0),
        .unsigned_a_i       (1'b1),
        .unsigned_b_i       (1'b1),

        .subtract_i         (1'b0)
    );

endmodule
