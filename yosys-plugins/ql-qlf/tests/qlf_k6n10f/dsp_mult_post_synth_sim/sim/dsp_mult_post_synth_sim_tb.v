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

`timescale 1ns/1ps

`define STRINGIFY(x) `"x`"

module tb();

    // Clock
    reg clk;
    initial clk <= 1'b0;
    always #1 clk <= ~clk;

    // Data Clock
    reg dclk;
    initial dclk <= 1'b0;
    always #2 dclk <= ~dclk;

    // Input data / reference
    reg [19:0] A0;

    reg [17:0] B0;

    reg [37:0] C0;

    always @(negedge dclk) begin
        A0 = $random;
        B0 = $random;

        C0 <= A0 * B0;
    end

    // UUT
    wire [37:0] Z0;

    case (`STRINGIFY(`TOP))
        "dsp_mult": begin
            dsp_mult dsp0 (
                .A(A0),
                .B(B0),
                .Z(Z0)
            );
        end
    endcase

    // Error detection
    wire error0 = (Z0 !== C0) && (C0 !== 38'bx);

    // Error counting
    integer error_count = 0;

    always @(posedge clk) begin
        if (error0) begin
            error_count <= error_count + 1'b1;
            $display("%d: DSP_0: FAIL: mismatch act=%x exp=%x at A0=%x; B0=%x", $time, Z0, C0, A0, B0);
        end else begin
            $display("%d: DSP_0: OK: act=%x exp=%x at A0=%x; B0=%x", $time, Z0, C0, A0, B0);
        end
    end

    // Simulation control / data dump
    initial begin
        $dumpfile(`STRINGIFY(`VCD));
        $dumpvars;
        #10000 $finish_and_return( (error_count == 0) ? 0 : -1 );
    end

endmodule
