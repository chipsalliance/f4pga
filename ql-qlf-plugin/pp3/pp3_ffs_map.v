// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module \$_DFFSRE_PPPP_ (
    input  C,
    S,
    R,
    E,
    D,
    output Q
);
  wire _TECHMAP_REMOVEINIT_Q_ = 1;
  dffepc _TECHMAP_REPLACE_ (
      .CLK(C),
      .PRE(S),
      .CLR(R),
      .EN (E),
      .D  (D),
      .Q  (Q)
  );
endmodule
