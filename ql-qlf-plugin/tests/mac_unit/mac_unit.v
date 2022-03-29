// Copyright (C) 2019-2022 The SymbiFlow Authors
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier: ISC

module mac_unit (
    a,
    b,
    out
);
  parameter DATA_WIDTH = 16;
  input [DATA_WIDTH - 1 : 0] a, b;
  output [2*DATA_WIDTH - 1 : 0] out;

  assign out = a * b + out;
endmodule

