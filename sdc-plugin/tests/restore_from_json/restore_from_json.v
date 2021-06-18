// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module top (
    input  clk,
    input  i,
    output o
);

  reg [0:0] outff = 0;

  assign o = outff;

  always @(posedge clk) begin
    outff <= i;
  end

endmodule
