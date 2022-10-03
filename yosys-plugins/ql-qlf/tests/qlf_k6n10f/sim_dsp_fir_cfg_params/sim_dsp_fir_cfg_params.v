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

`include "qlf_k6n10f/cells_sim.v"

module tb();

    // Clock
    reg clk;
    initial clk <= 1'b0;
    always #0.5 clk <= ~clk;

    // Reset
    reg rst;
    initial begin
            rst <= 1'b0;
        #2  rst <= 1'b1;
        #2  rst <= 1'b0;
    end

    // Filter control
    reg [2:0] fcnt;
    reg [3:0] dcnt;

    initial begin
        fcnt <= 0;
        dcnt <= 0;
    end

    // MAC cycle counter
    always @(posedge clk)
        if (rst) fcnt <= 0;
        else begin
            if (fcnt == 4)
                fcnt <= 0;
            else
                fcnt <= fcnt + 1;
        end

    wire stb = (fcnt == 4);

    // Data address counter
    always @(posedge clk)
        if (rst)      dcnt <= 0;
        else if (stb) dcnt <= dcnt + 1;

    // Filter coeffs (S0.19)
    reg signed [19:0] coeff;
    always @(*) case (fcnt)
        2'd0: coeff <= 20'h0000B;
        2'd1: coeff <= 20'h0000E;
        2'd2: coeff <= 20'h0000E;
        2'd3: coeff <= 20'h0000F;

        default: coeff <= 20'h00000;
    endcase

    // Input data (S0.17)
    reg signed [17:0] data;
    always @(*) case (dcnt)
        'd0:  data  <= 18'h00400;
        'd1:  data  <= 18'h00000;
        'd2:  data  <= 18'h00000;
        'd3:  data  <= 18'h00000;
        'd4:  data  <= 18'h00000;
        'd5:  data  <= 18'h00000;
        'd6:  data  <= 18'h00000;
        'd7:  data  <= 18'h00000;
        'd8:  data  <= 18'h00800;
        default data <= 18'h00000;
    endcase

    // UUT
    wire signed [5:0] acc_fir_i = 6'h0;
    wire signed [19:0] A = coeff;
    wire signed [17:0] B = data;
    wire signed [37:0] Z;

    dsp_t1_sim_cfg_params # (
        .SHIFT_RIGHT        (6'd10),
        .REGISTER_INPUTS    (1'b0),
        .OUTPUT_SELECT      (3'h1),
        .ROUND              (1'b1),
        .SATURATE_ENABLE    (1'b1)
    ) uut (
        .clock_i            (clk),
        .s_reset            (rst),
        .a_i                ((!stb) ? A : 20'h0),
        .b_i                ((!stb) ? B : 18'h0),
        .acc_fir_i          ((!stb) ? acc_fir_i : 4'h0),
        .unsigned_a_i       (1'b0),
        .unsigned_b_i       (1'b0),
        .feedback_i         (stb),
        .load_acc_i         (1'b1),
        .subtract_i         (1'b0),
        .z_o                (Z)
    );

    // Output counter
    integer ocnt;
    initial ocnt <= 0;

    always @(posedge clk)
        if (stb) ocnt <= ocnt + 1;

    // Expected output data
    reg signed [31:0] odata;
    always @(*) case (ocnt)
    'd0: odata <= 32'h000036;
    'd1: odata <= 32'h000000;
    'd2: odata <= 32'h000000;
    'd3: odata <= 32'h000000;
    'd4: odata <= 32'h000000;
    'd5: odata <= 32'h000000;
    'd6: odata <= 32'h000000;
    'd7: odata <= 32'h000000;
    'd8: odata <= 32'h00006C;
    default: odata <= 32'h000000;
    endcase

    // Error detection
    wire error = stb && (odata !== Z[31:0]);

    // Error counting
    integer error_count;
    initial error_count <= 0;
    always @(posedge clk) begin
        if (error) error_count <= error_count + 1;
    end

    // Simulation control / data dump
    initial begin
        $dumpfile(`VCD_FILE);
        $dumpvars(0, tb);
        #150 $finish_and_return( (error_count == 0) ? 0 : -1 );
    end

endmodule
