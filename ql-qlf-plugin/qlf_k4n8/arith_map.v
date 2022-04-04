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

(* techmap_celltype = "$alu" *)
module _80_quicklogic_alu (A, B, CI, BI, X, Y, CO);
    parameter A_SIGNED = 0;
    parameter B_SIGNED = 0;
    parameter A_WIDTH  = 1;
    parameter B_WIDTH  = 1;
    parameter Y_WIDTH  = 1;

    parameter _TECHMAP_CONSTMSK_CI_ = 0;
    parameter _TECHMAP_CONSTVAL_CI_ = 0;

    (* force_downto *)
    input [A_WIDTH-1:0] A;
    (* force_downto *)
    input [B_WIDTH-1:0] B;
    (* force_downto *)
    output [Y_WIDTH-1:0] X, Y;

    input CI, BI;
    (* force_downto *)
    output [Y_WIDTH-1:0] CO;

    wire _TECHMAP_FAIL_ = Y_WIDTH <= 2;

    (* force_downto *)
    wire [Y_WIDTH-1:0] A_buf, B_buf;
    \$pos #(.A_SIGNED(A_SIGNED), .A_WIDTH(A_WIDTH), .Y_WIDTH(Y_WIDTH)) A_conv (.A(A), .Y(A_buf));
    \$pos #(.A_SIGNED(B_SIGNED), .A_WIDTH(B_WIDTH), .Y_WIDTH(Y_WIDTH)) B_conv (.A(B), .Y(B_buf));

    (* force_downto *)
    wire [Y_WIDTH-1:0] AA = A_buf;
    (* force_downto *)
    wire [Y_WIDTH-1:0] BB = BI ? ~B_buf : B_buf;
    (* force_downto *)
    wire [Y_WIDTH-1:0] C;

    assign CO = C;

    genvar i;
    generate for (i = 0; i < Y_WIDTH; i = i + 1) begin: slice

        wire ci;
        wire co;

        // First in chain
        generate if (i == 0) begin

            // CI connected to a constant
            if (_TECHMAP_CONSTMSK_CI_ == 1) begin

                localparam INIT = (_TECHMAP_CONSTVAL_CI_ == 0) ?
                    16'b0110_0110_0000_1000:
                    16'b1001_1001_0000_1110;

                // LUT4 configured as 1-bit adder with CI=const
                adder_lut4 #(
                    .LUT(INIT),
                    .IN2_IS_CIN(1'b0)
                ) lut_ci_adder (
                    .in({AA[i], BB[i], 1'b1, 1'b1}),
                    .cin(), 
                    .lut4_out(Y[i]), 
                    .cout(ci)
                );

            // CI connected to a non-const driver
            end else begin

                // LUT4 configured as passthrough to drive CI of the next stage
                adder_lut4 #(
                    .LUT(16'b0000_0000_0000_1100),
                    .IN2_IS_CIN(1'b0)
                ) lut_ci (
                    .in({1'b1, CI, 1'b1, 1'b1}),
                    .cin(), 
                    .lut4_out(), 
                    .cout(ci)
                );
            end

        // Not first in chain
        end else begin
            assign ci = C[i-1];

        end endgenerate

        // ....................................................

        // Single 1-bit adder, mid-chain adder or non-const CI
        // adder
        generate if ((i == 0 && _TECHMAP_CONSTMSK_CI_ == 0) || (i > 0)) begin
            
            // LUT4 configured as full 1-bit adder
            adder_lut4 #(
                    .LUT(16'b1001_0110_0110_1000),
                    .IN2_IS_CIN(1'b1)
                ) lut_adder (
                    .in({AA[i], BB[i], 1'b1, 1'b1}),
                    .cin(ci), 
                    .lut4_out(Y[i]), 
                    .cout(co)
                );
        end else begin
            assign co = ci;

        end endgenerate

        // ....................................................

        // Last in chain
        generate if (i == Y_WIDTH-1) begin

            // LUT4 configured for passing its CI input to output. This should
            // get pruned if the actual CO port is not connected anywhere.
            adder_lut4 #(
                    .LUT(16'b1111_0000_1111_0000),
                    .IN2_IS_CIN(1'b1)
                ) lut_co (
                    .in({1'b1, 1'b1, 1'b1, 1'b1}),
                    .cin(co),
                    .lut4_out(C[i]),
                    .cout()
                );
        // Not last in chain
        end else begin
            assign C[i] = co;

        end endgenerate

    end: slice	  
    endgenerate

    /* End implementation */
    assign X = AA ^ BB;
endmodule
