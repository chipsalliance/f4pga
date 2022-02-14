// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module mult_16x16 (
    input  wire [15:0] A,
    input  wire [15:0] B,
    output wire [31:0] Z
);

    assign Z = A * B;

endmodule

module mult_20x18 (
    input  wire [19:0] A,
    input  wire [17:0] B,
    output wire [37:0] Z
);

    assign Z = A * B;

endmodule

module mult_8x8 (
    input  wire [ 7:0] A,
    input  wire [ 7:0] B,
    output wire [15:0] Z
);

    assign Z = A * B;

endmodule

module mult_10x9 (
    input  wire [ 9:0] A,
    input  wire [ 8:0] B,
    output wire [18:0] Z
);

    assign Z = A * B;

endmodule
