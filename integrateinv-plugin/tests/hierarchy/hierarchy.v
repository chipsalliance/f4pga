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

(* keep_hierarchy *)
module child (
    input  wire       I,
    output wire [1:0] O
);

    wire d;

    \$_NOT_ n (.A(I), .Y(d));

    box b0 (.A(I), .Y(O[0]));
    box b1 (.A(d), .Y(O[1]));

endmodule


module top(
    input  wire       di,
    output wire [4:0] do
);

    wire [1:0] d;

    \$_NOT_ n0 (.A(di), .Y(d[0]));
    \$_NOT_ n1 (.A(di), .Y(d[1]));

    box   b0 (.A(d[0]), .Y(do[0]));
    box   b1 (.A(d[1]), .Y(do[1]));
    child c  (.I(d[1]), .O({do[3], do[2]}));

endmodule
