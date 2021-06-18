// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

(* blackbox *)
module box(
    (* invertible_pin="INV_A" *)
    input  wire A,
    output wire Y
);

    parameter [0:0] INV_A = 1'b0;

endmodule


module top(
    input  wire [1:0]  di,
    output wire [2:0]  do
);

    wire [1:0] d;

    \$_NOT_ n0 (.A(di[0]), .Y(d[0]));
    \$_NOT_ n1 (.A(di[1]), .Y(d[1]));

    box b0 (.A(d[0]), .Y(do[0]));
    box b1 (.A(d[1]), .Y(do[1]));
    assign do[0] = d[0];

endmodule
