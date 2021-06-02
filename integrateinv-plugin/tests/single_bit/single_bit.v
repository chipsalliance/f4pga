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
    input  wire B,
    (* invertible_pin="INV_C" *)
    input  wire C,
    input  wire D,

    output wire Y
);

    parameter [0:0] INV_A = 1'b0;
    parameter [0:0] INV_C = 1'b0;

endmodule


module top(
    input  wire [3:0] di,
    output wire       do
);

    wire [3:0] d;

    \$_NOT_ n0 (.A(di[0]), .Y(d[0]));
    \$_NOT_ n1 (.A(di[1]), .Y(d[1]));
    \$_NOT_ n2 (.A(di[2]), .Y(d[2]));
    \$_NOT_ n3 (.A(di[3]), .Y(d[3]));

    box #(.INV_A(1'b1)) the_box (
        .A (d[0]),
        .B (d[1]),
        .C (d[2]),
        .D (d[3]),

        .Y (do)
    );

endmodule
