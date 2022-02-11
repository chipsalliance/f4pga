// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module conflict_out_fanout (
    input  wire        CLK,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output reg  [17:0] Z,
    output wire [ 8:0] X,
);

    wire [17:0] z;
    always @(posedge CLK)
        Z <= z;

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A (A),
        .B (B),
        .Z (z)
    );

    assign X = ~z[8:0];

endmodule

module conflict_out_fanout_to_top (
    input  wire        CLK,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output reg  [17:0] Z,
    output wire [ 8:0] X,
);

    wire [17:0] z;
    always @(posedge CLK)
        Z <= z;

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A (A),
        .B (B),
        .Z (z)
    );

    assign X = z[8:0];

endmodule

module conflict_inp_fanout (
    input  wire        CLK,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output reg  [17:0] Z,
    output wire [ 3:0] X,
);

    wire [8:0] ra;
    always @(posedge CLK)
        ra <= A;

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A (ra),
        .B (B),
        .Z (Z)
    );

    assign X = ~ra[3:0];

endmodule

module conflict_inp_fanout_to_top (
    input  wire        CLK,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output reg  [17:0] Z,
    output wire [ 3:0] X,
);

    wire [8:0] ra;
    always @(posedge CLK)
        ra <= A;

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A (ra),
        .B (B),
        .Z (Z)
    );

    assign X = ra[3:0];

endmodule

