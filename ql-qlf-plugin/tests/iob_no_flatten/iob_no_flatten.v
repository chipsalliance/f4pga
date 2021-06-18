// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module my_dff (
    input d,
    clk,
    output reg q
);
  always @(posedge clk) q <= d;
endmodule

module my_top (
    inout  wire pad,
    input  wire i,
    input  wire t,
    output wire o,
    input  wire clk
);

  wire i_r;
  wire t_r;
  wire o_r;

  // IOB
  assign pad = (t_r) ? i_r : 1'bz;
  assign o_r = pad;

  // DFFs
  my_dff dff_i (
      i,
      clk,
      i_r
  );
  my_dff dff_t (
      t,
      clk,
      t_r
  );
  my_dff dff_o (
      o_r,
      clk,
      o
  );

endmodule
