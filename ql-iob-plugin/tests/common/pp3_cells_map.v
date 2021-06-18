// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module \$_DFF_P_ (
    D,
    Q,
    C
);
  input D;
  input C;
  output Q;
  dff _TECHMAP_REPLACE_ (
      .Q  (Q),
      .D  (D),
      .CLK(C)
  );
endmodule

