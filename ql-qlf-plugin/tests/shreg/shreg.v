// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module top (
    input  wire I,
    input  wire C,
    output wire O
);

  reg [7:0] shift_register;

  always @(posedge C) shift_register <= {shift_register[6:0], I};

  assign O = shift_register[7];

endmodule
