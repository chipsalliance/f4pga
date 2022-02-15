// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

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
    wire signed [19:0] A = coeff;
    wire signed [17:0] B = data;
    wire signed [37:0] Z;

    dsp_t1_sim # (
        .REGISTER_INPUTS    (1'b0),
        .OUTPUT_SELECT      (3'h1),
        .ROUND              (1'b1),
        .SATURATE_ENABLE    (1'b1)
    ) uut (
        .clock_i        (clk),
        .reset_n_i      (~rst),
        .a_i            ((!stb) ? A : 'h0),
        .b_i            ((!stb) ? B : 'h0),
        .unsigned_a_i   (1'b0),
        .unsigned_b_i   (1'b0),
        .feedback_i     (stb),
        .load_acc_i     (1'b1),
        .shift_right_i  (6'd10),
        .z_o            (Z)
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
    wire error = stb && (odata != Z[31:0]);

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
