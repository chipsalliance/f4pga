// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module top (
    input [0:7] in,
    output B1,
    B2,
    B3,
    B4,
    B5,
    B6,
    B7,
    B8,
    B9,
    B10
);
  assign B1  = in[0] & in[1];
  assign B2  = in[0] | in[1];
  assign B3  = in[0]~&in[1];
  assign B4  = in[0]~|in[1];
  assign B5  = in[0] ^ in[1];
  assign B6  = in[0] ~^ in[1];
  assign B7  = ~in[0];
  assign B8  = in[0];
  assign B9  = in[0:1] && in[2:3];
  assign B10 = in[0:1] || in[2:3];
endmodule
