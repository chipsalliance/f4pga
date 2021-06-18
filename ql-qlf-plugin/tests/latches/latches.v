// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module latchp (
    input d,
    clk,
    en,
    output reg q
);
  initial q <= 1'b0;
  always @* if (en) q <= d;
endmodule

module latchn (
    input d,
    clk,
    en,
    output reg q
);
  always @* if (!en) q <= d;
endmodule

module my_latchsre (
    input d,
    clk,
    en,
    clr,
    pre,
    output reg q
);
  always @*
    if (clr) q <= 1'b0;
    else if (pre) q <= 1'b1;
    else if (en) q <= d;
endmodule

module latchp_noinit (
    input d,
    clk,
    en,
    output reg q
);
  always @* if (en) q <= d;
endmodule
