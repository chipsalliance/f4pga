// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module mult_wide (
    input  wire        CLK,
    input  wire [ 8:0] A0,
    input  wire [ 8:0] A1,
    input  wire [ 8:0] A2,
    input  wire [ 8:0] A3,
    input  wire [ 8:0] B0,
    input  wire [ 8:0] B1,
    input  wire [ 8:0] B2,
    input  wire [ 8:0] B3,
    input  wire [53:0] C,
    output wire [53:0] Z
);

    reg [8:0] ra0;
    always @(posedge CLK)
        ra0 <= A0;

    reg [8:0] rb0;
    always @(posedge CLK)
        rb0 <= B0;

    reg [8:0] rb2;
    always @(posedge CLK)
        rb2 <= B2;

    MULTADDSUB9X9WIDE # (
        .REGINPUTAB0("BYPASS"),
        .REGINPUTAB1("BYPASS"),
        .REGINPUTAB2("BYPASS"),
        .REGINPUTAB3("BYPASS"),
        .REGINPUTC("BYPASS"),
        .REGADDSUB("BYPASS"),
        .REGLOADC("BYPASS"),
        .REGLOADC2("BYPASS"),
        .REGPIPELINE("BYPASS"),
        .REGOUTPUT("REGISTER")
    ) mult (
        .A0 (ra0),
        .A1 (A1),
        .A2 (A2),
        .A3 (A3),
        .B0 (rb0),
        .B1 (B1),
        .B2 (rb2),
        .B3 (B3),
        .C  (C),
        .Z  (Z),

        .LOADC      (1'b0),
        .ADDSUB     (4'hF),
        .SIGNED     (1'b1),
    );

endmodule
