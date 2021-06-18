// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module full_adder (
    input  wire [`WIDTH-1:0] A,
    input  wire [`WIDTH-1:0] B,
    output wire [`WIDTH  :0] S,
);

    // Implicit adder
    assign S = A + B;

endmodule

module subtractor (
    input  wire [`WIDTH-1:0] A,
    input  wire [`WIDTH-1:0] B,
    output wire [`WIDTH  :0] S,
);

    // Implicit subtractor
    assign S = A - B;

endmodule
