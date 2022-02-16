// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module mult_ireg (
    input  wire        CLK,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [8:0] ra;
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

endmodule

module mult_oreg (
    input  wire        CLK,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output reg  [17:0] Z
);

    reg [17:0] z;
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

endmodule

module mult_all (
    input  wire        CLK,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output reg  [17:0] Z
);

    reg [8:0] ra;
    always @(posedge CLK)
        ra <= A;

    reg [8:0] rb;
    always @(posedge CLK)
        rb <= B;

    reg [17:0] z;
    always @(posedge CLK)
        Z <= z;

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A (ra),
        .B (rb),
        .Z (z)
    );

endmodule

module mult_ctrl (
    input  wire        CLK,
    input  wire [ 8:0] A,
    input  wire        SA,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [8:0] ra;
    reg       rsa;

    always @(posedge CLK) begin
        ra  <= A;
        rsa <= SA;
    end

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A          (ra),
        .SIGNEDA    (rsa),
        .B          (B),
        .Z          (Z)
    );

endmodule

