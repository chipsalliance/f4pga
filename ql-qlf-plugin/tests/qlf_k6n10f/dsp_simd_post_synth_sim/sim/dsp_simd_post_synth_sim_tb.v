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
    reg [9:0] A0;
    reg [9:0] A1;

    reg [8:0] B0;
    reg [8:0] B1;

    reg [18:0] C0;
    reg [18:0] C1;

    always @(negedge dclk) begin
        A0 = $random;
        B0 = $random;

        C0 <= A0 * B0;

        A1 = $random;
        B1 = $random;

        C1 <= A1 * B1;
    end

    // UUT
    wire [18:0] Z0;
    wire [18:0] Z1;

    case (`STRINGIFY(`TOP))
        "simd_mult": begin
            simd_mult dsp0 (
                .clk(clk),
                .a0(A0),
                .a1(A1),
                .b0(B0),
                .b1(B1),
                .z0(Z0),
                .z1(Z1));
        end
        "simd_mult_explicit_ports": begin
            simd_mult_explicit_ports dsp1 (
                .clk(clk),
                .a0(A0),
                .a1(A1),
                .b0(B0),
                .b1(B1),
                .z0(Z0),
                .z1(Z1));
        end
        "simd_mult_explicit_params": begin
            simd_mult_explicit_params dsp1 (
                .clk(clk),
                .a0(A0),
                .a1(A1),
                .b0(B0),
                .b1(B1),
                .z0(Z0),
                .z1(Z1));
        end
    endcase

    reg [18:0] C0_r;
    reg [18:0] C1_r;

    always @(posedge clk) begin
        C0_r = C0;
        C1_r = C1;
    end

    // Error detection
    wire error0 = (Z0 !== C0_r) && (C0_r !== 19'bx);
    wire error1 = (Z1 !== C1_r) && (C0_r !== 19'bx);

    // Error counting
    integer error_count = 0;

    always @(posedge clk) begin
        if (error0) begin
            error_count <= error_count + 1'b1;
            $display("%d: DSP_0: FAIL: mismatch act=%x exp=%x at A0=%x; B0=%x", $time, Z0, C0_r, A0, B0);
        end else begin
            $display("%d: DSP_0: OK: act=%x exp=%x at A0=%x; B0=%x", $time, Z0, C0_r, A0, B0);
        end
    end

    always @(posedge clk) begin
        if (error1) begin
            error_count <= error_count + 1'b1;
            $display("%d: DSP_1: FAIL: mismatch act=%x exp=%x at A1=%x; B1=%x", $time, Z1, C1_r, A1, B1);
        end else begin
            $display("%d: DSP_1: OK: act=%x exp=%x at A1=%x; B1=%x", $time, Z1, C1_r, A1, B1);
        end
    end

    // Simulation control / data dump
    initial begin
        $dumpfile(`STRINGIFY(`VCD));
        $dumpvars;
        #10000 $finish_and_return( (error_count == 0) ? 0 : -1 );
    end

endmodule
