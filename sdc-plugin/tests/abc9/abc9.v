// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module top (
    input  clk1,
    clk2,
    output led1,
    led2
);

  reg [15:0] counter1 = 0;
  reg [15:0] counter2 = 0;

  assign led1 = counter1[15];
  assign led2 = counter2[15];

  always @(posedge clk1) counter1 <= counter1 + 1;

  always @(posedge clk2) counter2 <= counter2 + 1;

endmodule
