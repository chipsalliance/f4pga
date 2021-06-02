// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC


module inv(output Q, input A);
    assign Q = A ? 0 : 1;
endmodule

module buff(output Q, input A);
    assign Q = A;
endmodule

module logic_0(output a);
    assign a = 0;
endmodule

module logic_1(output a);
    assign a = 1;
endmodule

(* blackbox *)
module gclkbuff (input A, output Z);

assign Z = A;

endmodule

