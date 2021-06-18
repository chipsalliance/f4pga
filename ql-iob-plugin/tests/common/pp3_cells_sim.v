// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module inpad (
    output Q,
    (* iopad_external_pin *)
    input  P
);
  assign Q = P;
endmodule

module outpad (
    (* iopad_external_pin *)
    output P,
    input  A
);
  assign P = A;
endmodule

module ckpad (
    output Q,
    (* iopad_external_pin *)
    input  P
);
  assign Q = P;
endmodule

module bipad (
    input  A,
    input  EN,
    output Q,
    (* iopad_external_pin *)
    inout  P
);
  assign Q = P;
  assign P = EN ? A : 1'bz;
endmodule


module dff (
    output reg Q,
    input D,
    (* clkbuf_sink *)
    input CLK
);
  parameter [0:0] INIT = 1'b0;
  initial Q = INIT;
  always @(posedge CLK) Q <= D;
endmodule

