// Copyright (C) 2019-2022 The SymbiFlow Authors
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier: ISC
module $__PP3_DFFEPC_SYNCONLY (
  output Q,
  input D,
  input CLK,
  input EN,
);

// For some reason ABC9 adds init attributes to wires even though they were removed before mapping.
// As a workaround, remove any init attributes that get reintroduced.
wire _TECHMAP_REMOVEINIT_Q_ = 1;

dffepc _TECHMAP_REPLACE_ (.Q(Q), .D(D), .CLK(CLK), .EN(EN), .PRE(1'b0), .CLR(1'b0));

endmodule
