// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module macc_simple (
    input  wire        clk,
    input  wire [ 7:0] A,
    input  wire [ 7:0] B,
    output reg  [15:0] Z
);

    always @(posedge clk)
        Z <= Z + (A * B);

endmodule

module macc_simple_clr (
    input  wire        clk,
    input  wire        clr,
    input  wire [ 7:0] A,
    input  wire [ 7:0] B,
    output reg  [15:0] Z
);

    always @(posedge clk)
        if (clr) Z <=     (A * B);
        else     Z <= Z + (A * B);

endmodule

module macc_simple_arst (
    input  wire        clk,
    input  wire        rst,
    input  wire [ 7:0] A,
    input  wire [ 7:0] B,
    output reg  [15:0] Z
);

    always @(posedge clk or posedge rst)
        if (rst) Z <= 0;
        else     Z <= Z + (A * B);

endmodule

module macc_simple_ena (
    input  wire        clk,
    input  wire        ena,
    input  wire [ 7:0] A,
    input  wire [ 7:0] B,
    output reg  [15:0] Z
);

    always @(posedge clk)
        if (ena) Z <= Z + (A * B);

endmodule

module macc_simple_arst_clr_ena (
    input  wire        clk,
    input  wire        rst,
    input  wire        clr,
    input  wire        ena,
    input  wire [ 7:0] A,
    input  wire [ 7:0] B,
    output reg  [15:0] Z
);

    always @(posedge clk or posedge rst)
        if (rst)     Z <= 0;
        else if (ena) begin
            if (clr) Z <=     (A * B);
            else     Z <= Z + (A * B);
        end

endmodule

module macc_simple_preacc (
    input  wire        clk,
    input  wire [ 7:0] A,
    input  wire [ 7:0] B,
    output wire [15:0] Z
);

    reg [15:0] acc;

    assign Z = acc + (A * B);

    always @(posedge clk)
        acc <= Z;

endmodule

module macc_simple_preacc_clr (
    input  wire        clk,
    input  wire        clr,
    input  wire [ 7:0] A,
    input  wire [ 7:0] B,
    output reg  [15:0] Z
);

    reg [15:0] acc;

    assign Z = (clr) ? (A * B) : (acc + (A * B));

    always @(posedge clk)
        acc <= Z;

endmodule

