// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module conflict_dsp_clk (
    input  wire        CLK_A,
    input  wire        CLK_B,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [8:0] ra;
    always @(posedge CLK_A)
        ra <= A;

    reg [8:0] rb;
    always @(posedge CLK_B)
        rb <= B;

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A (ra),
        .B (rb),
        .Z (Z)
    );

endmodule

module conflict_ff_clk (
    input  wire        CLK1,
    input  wire        CLK2,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [17:0] z;

    always @(posedge CLK1)
        Z[17:9] <= z[17:9];
    always @(posedge CLK2)
        Z[ 8:0] <= z[ 8:0];

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

module conflict_ff_rst (
    input  wire        CLK,
    input  wire        RST1,
    input  wire        RST2,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [17:0] z;

    always @(posedge CLK or posedge RST1)
        if (RST1)
            Z[17:9] <= 0;
        else
            Z[17:9] <= z[17:9];
    always @(posedge CLK or posedge RST2)
        if (RST2)
            Z[ 8:0] <= 0;
        else
            Z[ 8:0] <= z[ 8:0];

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

module conflict_ff_ena (
    input  wire        CLK,
    input  wire        ENA1,
    input  wire        ENA2,
    input  wire [ 8:0] A,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [17:0] z;

    always @(posedge CLK)
        if (ENA1)
            Z[17:9] <= z[17:9];
    always @(posedge CLK)
        if (ENA2)
            Z[ 8:0] <= z[ 8:0];

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

module conflict_dsp_port (
    input  wire        CLK_A,
    input  wire [ 8:0] A,
    input  wire        SA,
    input  wire [ 8:0] B,
    output wire [17:0] Z
);

    reg [8:0] ra;
    always @(posedge CLK_A)
        ra <= A;

    MULT9X9 # (
        .REGINPUTA("BYPASS"),
        .REGINPUTB("BYPASS"),
        .REGOUTPUT("BYPASS")
    ) mult (
        .A       (ra),
        .SIGNEDA (SA),
        .B       (B),
        .Z       (Z)
    );

endmodule
