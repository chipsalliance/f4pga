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

module macc_simple_arst_clr (
    input  wire        clk,
    input  wire        rst,
    input  wire        clr,
    input  wire [ 7:0] A,
    input  wire [ 7:0] B,
    output reg  [15:0] Z
);

    always @(posedge clk or posedge rst)
        if (rst)     Z <= 0;
        else begin
            if (clr) Z <=     (A * B);
            else     Z <= Z + (A * B);
        end

endmodule
