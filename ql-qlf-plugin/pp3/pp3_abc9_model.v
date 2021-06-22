// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

(* abc9_flop, lib_whitebox *)
module $__PP3_DFFEPC_SYNCONLY (
  output Q,
  input D,
  input CLK,
  input EN,
);

  dffepc ff (.Q(Q), .D(D), .CLK(CLK), .EN(EN), .PRE(1'b0), .CLR(1'b0));

endmodule
