// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

module my_dff (
    input d,
    clk,
    output reg q
);
  always @(posedge clk) q <= d;
endmodule

module my_dffr_p (
    input d,
    clk,
    clr,
    output reg q
);
  always @(posedge clk or posedge clr)
    if (clr) q <= 1'b0;
    else q <= d;
endmodule

module my_dffr_p_2 (
    input d1,
    input d2,
    clk,
    clr,
    output reg q1,
    output reg q2
);
  always @(posedge clk or posedge clr)
    if (clr) begin 
     q1 <= 1'b0;
     q2 <= 1'b0;
    end else begin
     q1 <= d1;
     q2 <= d2;
    end
endmodule

module my_dffr_n (
    input d,
    clk,
    clr,
    output reg q
);
  always @(posedge clk or negedge clr)
    if (!clr) q <= 1'b0;
    else q <= d;
endmodule

module my_dffre_p (
    input d,
    clk,
    clr,
    en,
    output reg q
);
  always @(posedge clk or posedge clr)
    if (clr) q <= 1'b0;
    else if (en) q <= d;
endmodule

module my_dffre_n (
    input d,
    clk,
    clr,
    en,
    output reg q
);
  always @(posedge clk or negedge clr)
    if (!clr) q <= 1'b0;
    else if (en) q <= d;
endmodule

module my_dffs_p (
    input d,
    clk,
    pre,
    output reg q
);
  always @(posedge clk or posedge pre)
    if (pre) q <= 1'b1;
    else q <= d;
endmodule

module my_dffs_n (
    input d,
    clk,
    pre,
    output reg q
);
  always @(posedge clk or negedge pre)
    if (!pre) q <= 1'b1;
    else q <= d;
endmodule

module my_dffse_p (
    input d,
    clk,
    pre,
    en,
    output reg q
);
  always @(posedge clk or posedge pre)
    if (pre) q <= 1'b1;
    else if(en) q <= d;
endmodule

module my_dffse_n (
    input d,
    clk,
    pre,
    en,
    output reg q
);
  always @(posedge clk or negedge pre)
    if (!pre) q <= 1'b1;
    else if(en) q <= d;
endmodule

module my_dffn (
    input d,
    clk,
    output reg q
);
  initial q <= 1'b0;
  always @(negedge clk) q <= d;
endmodule

module my_dffnr_p (
    input d,
    clk,
    clr,
    output reg q
);
  initial q <= 1'b0;
  always @(negedge clk or posedge clr)
    if (clr) q <= 1'b0;
    else q <= d;
endmodule

module my_dffnr_n (
    input d,
    clk,
    clr,
    output reg q
);
  initial q <= 1'b0;
  always @(negedge clk or negedge clr)
    if (!clr) q <= 1'b0;
    else q <= d;
endmodule


module my_dffns_p (
    input d,
    clk,
    pre,
    output reg q
);
  initial q <= 1'b0;
  always @(negedge clk or posedge pre)
    if (pre) q <= 1'b1;
    else q <= d;
endmodule

module my_dffns_n (
    input d,
    clk,
    pre,
    output reg q
);
  initial q <= 1'b0;
  always @(negedge clk or negedge pre)
    if (!pre) q <= 1'b1;
    else q <= d;
endmodule

module my_dffsr_ppp (
    input d,
    clk,
    pre,
    clr,
    output reg q
);
  initial q <= 1'b0;
  always @(posedge clk or posedge pre or posedge clr)
    if (pre) q <= 1'b1;
    else if (clr) q <= 1'b0;
    else q <= d;
endmodule

module my_dffsr_pnp (
    input d,
    clk,
    pre,
    clr,
    output reg q
);
  initial q <= 1'b0;
  always @(posedge clk or negedge pre or posedge clr)
    if (!pre) q <= 1'b1;
    else if (clr) q <= 1'b0;
    else q <= d;
endmodule

module my_dffsr_ppn (
    input d,
    clk,
    pre,
    clr,
    output reg q
);
  initial q <= 1'b0;
  always @(posedge clk or posedge pre or negedge clr)
    if (pre) q <= 1'b1;
    else if (!clr) q <= 1'b0;
    else q <= d;
endmodule

module my_dffsr_pnn (
    input d,
    clk,
    pre,
    clr,
    output reg q
);
  initial q <= 1'b0;
  always @(posedge clk or negedge pre or negedge clr)
    if (!pre) q <= 1'b1;
    else if (!clr) q <= 1'b0;
    else q <= d;
endmodule

module my_dffsr_npp (
    input d,
    clk,
    pre,
    clr,
    output reg q
);
  initial q <= 1'b0;
  always @(negedge clk or posedge pre or posedge clr)
    if (pre) q <= 1'b1;
    else if (clr) q <= 1'b0;
    else q <= d;
endmodule

module my_dffsr_nnp (
    input d,
    clk,
    pre,
    clr,
    output reg q
);
  initial q <= 1'b0;
  always @(negedge clk or negedge pre or posedge clr)
    if (!pre) q <= 1'b1;
    else if (clr) q <= 1'b0;
    else q <= d;
endmodule

module my_dffsr_npn (
    input d,
    clk,
    pre,
    clr,
    output reg q
);
  initial q <= 1'b0;
  always @(negedge clk or posedge pre or negedge clr)
    if (pre) q <= 1'b1;
    else if (!clr) q <= 1'b0;
    else q <= d;
endmodule

module my_dffsr_nnn (
    input d,
    clk,
    pre,
    clr,
    output reg q
);
  initial q <= 1'b0;
  always @(negedge clk or negedge pre or negedge clr)
    if (!pre) q <= 1'b1;
    else if (!clr) q <= 1'b0;
    else q <= d;
endmodule

module my_dffsre_ppp (
    input d,
    clk,
    pre,
    clr,
    en,
    output reg q
);
  initial q <= 1'b0;
  always @(posedge clk or posedge pre or posedge clr)
    if (pre) q <= 1'b1;
    else if (clr) q <= 1'b0;
    else if (en) q <= d;
endmodule

module my_dffsre_pnp (
    input d,
    clk,
    pre,
    clr,
    en,
    output reg q
);
  initial q <= 1'b0;
  always @(posedge clk or negedge pre or posedge clr)
    if (!pre) q <= 1'b1;
    else if (clr) q <= 1'b0;
    else if (en) q <= d;
endmodule

module my_dffsre_ppn (
    input d,
    clk,
    pre,
    clr,
    en,
    output reg q
);
  initial q <= 1'b0;
  always @(posedge clk or posedge pre or negedge clr)
    if (pre) q <= 1'b1;
    else if (!clr) q <= 1'b0;
    else if (en) q <= d;
endmodule

module my_dffsre_pnn (
    input d,
    clk,
    pre,
    clr,
    en,
    output reg q
);
  initial q <= 1'b0;
  always @(posedge clk or negedge pre or negedge clr)
    if (!pre) q <= 1'b1;
    else if (!clr) q <= 1'b0;
    else if (en) q <= d;
endmodule

module my_dffsre_npp (
    input d,
    clk,
    pre,
    clr,
    en,
    output reg q
);
  initial q <= 1'b0;
  always @(negedge clk or posedge pre or posedge clr)
    if (pre) q <= 1'b1;
    else if (clr) q <= 1'b0;
    else if (en) q <= d;
endmodule

module my_dffsre_nnp (
    input d,
    clk,
    pre,
    clr,
    en,
    output reg q
);
  initial q <= 1'b0;
  always @(negedge clk or negedge pre or posedge clr)
    if (!pre) q <= 1'b1;
    else if (clr) q <= 1'b0;
    else if (en) q <= d;
endmodule

module my_dffsre_npn (
    input d,
    clk,
    pre,
    clr,
    en,
    output reg q
);
  initial q <= 1'b0;
  always @(negedge clk or posedge pre or negedge clr)
    if (pre) q <= 1'b1;
    else if (!clr) q <= 1'b0;
    else if (en) q <= d;
endmodule

module my_dffsre_nnn (
    input d,
    clk,
    pre,
    clr,
    en,
    output reg q
);
  initial q <= 1'b0;
  always @(negedge clk or negedge pre or negedge clr)
    if (!pre) q <= 1'b1;
    else if (!clr) q <= 1'b0;
    else if (en) q <= d;
endmodule
