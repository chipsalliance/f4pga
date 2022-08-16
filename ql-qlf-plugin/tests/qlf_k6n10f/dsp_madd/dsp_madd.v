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

module madd_simple_ports (
    input  wire [ 9:0] A,
    input  wire [ 8:0] B,
    input  wire [ 1:0] C,
    output reg  [18:0] Z
);

    // There is no support for autmoatic inference of multiply+add hence the
    // DSP cell needs to be instanced manually.
    //
    // To test the type change the "is_inferred" attribute is set here
    // explicitily to mimic possible inference

    // B * coeff[C] + A
    (* is_inferred=1 *)
    dsp_t1_10x9x32_cfg_ports # (
        .COEFF_0            (10'h011),
        .COEFF_1            (10'h022),
        .COEFF_2            (10'h033),
        .COEFF_3            (10'h044)
    ) dsp (
        .a_i                (A),
        .b_i                (B),
        .acc_fir_i          (6'd0),
        .z_o                (Z),
        .dly_b_o            (),

        .feedback_i         ({1'b1, C}), // 4-7
        .output_select_i    (3'd3),
        .register_inputs_i  (1'b0),

        .unsigned_a_i       (1'b1),
        .unsigned_b_i       (1'b1),
        .load_acc_i         (1'b1),

        .saturate_enable_i  (1'b0),
        .shift_right_i      (6'd0),
        .round_i            (1'b0),
        .subtract_i         (1'b0)
    );

endmodule

module madd_simple_params (
    input  wire [ 9:0] A,
    input  wire [ 8:0] B,
    input  wire [ 1:0] C,
    output reg  [18:0] Z
);

    // There is no support for autmoatic inference of multiply+add hence the
    // DSP cell needs to be instanced manually.
    //
    // To test the type change the "is_inferred" attribute is set here
    // explicitily to mimic possible inference

    // B * coeff[C] + A
    (* is_inferred=1 *)
    dsp_t1_10x9x32_cfg_params # (
        .COEFF_0            (10'h011),
        .COEFF_1            (10'h022),
        .COEFF_2            (10'h033),
        .COEFF_3            (10'h044),

        .OUTPUT_SELECT      (3'd3),
        .SATURATE_ENABLE    (1'b0),
        .SHIFT_RIGHT        (6'd0),
        .ROUND              (1'b0),
        .REGISTER_INPUTS    (1'b0)
    ) dsp (
        .a_i                (A),
        .b_i                (B),
        .acc_fir_i          (6'd0),
        .z_o                (Z),
        .dly_b_o            (),

        .feedback_i         ({1'b1, C}), // 4-7

        .unsigned_a_i       (1'b1),
        .unsigned_b_i       (1'b1),
        .load_acc_i         (1'b1),

        .subtract_i         (1'b0)
    );

endmodule

// ............................................................................
