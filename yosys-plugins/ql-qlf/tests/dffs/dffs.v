// Copyright 2020-2022 F4PGA Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

module my_dff (
    input d,
    clk,
    output reg q
);
  always @(posedge clk) q <= d;
endmodule

module my_dffe (
    input d,
    clk,
    en,
    output reg q
);
  initial begin
    q = 0;
  end
  always @(posedge clk) if (en) q <= d;
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
    else if (en) q <= d;
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
    else if (en) q <= d;
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

module my_sdffr_n (
    input d,
    clk,
    clr,
    output reg q
);
  initial q <= 0;
  always @(posedge clk)
    if (!clr) q <= 1'b0;
    else q <= d;
endmodule

module my_sdffs_n (
    input d,
    clk,
    pre,
    output reg q
);
  initial q <= 0;
  always @(posedge clk)
    if (!pre) q <= 1'b1;
    else q <= d;
endmodule

module my_sdffnr_n (
    input d,
    clk,
    clr,
    output reg q
);
  initial q <= 0;
  always @(negedge clk)
    if (!clr) q <= 1'b0;
    else q <= d;
endmodule

module my_sdffns_n(
    input d,
    clk,
    pre,
    output reg q
);
  initial q <= 0;
  always @(negedge clk)
    if (!pre) q <= 1'b1;
    else q <= d;
endmodule

module my_sdffr_p (
    input d,
    clk,
    clr,
    output reg q
);
  initial q <= 0;
  always @(posedge clk)
    if (clr) q <= 1'b0;
    else q <= d;
endmodule

module my_sdffs_p (
    input d,
    clk,
    pre,
    output reg q
);
  initial q <= 0;
  always @(posedge clk)
    if (pre) q <= 1'b1;
    else q <= d;
endmodule

module my_sdffnr_p (
    input d,
    clk,
    clr,
    output reg q
);
  initial q <= 0;
  always @(negedge clk)
    if (clr) q <= 1'b0;
    else q <= d;
endmodule

module my_sdffns_p (
    input d,
    clk,
    pre,
    output reg q
);
  initial q <= 0;
  always @(negedge clk)
    if (pre) q <= 1'b1;
    else q <= d;
endmodule


module my_latch (
    input  wire d, g,
    output reg  q
);
    always @(*)
        if (g) q <= d;
endmodule

module my_latchn (
    input  wire d, g,
    output reg  q
);
    always @(*)
        if (!g) q <= d;
endmodule


module my_latchs_p (
    input  wire d, g, s,
    output reg  q
);
    always @(*)
        if (s)
            q <= 1'b1;
        else if (g)
            q <= d;
endmodule

module my_latchs_n (
    input  wire d, g, s,
    output reg  q
);
    always @(*)
        if (!s)
            q <= 1'b1;
        else if (g)
            q <= d;
endmodule

module my_latchr_p (
    input  wire d, g, r,
    output reg  q
);
    always @(*)
        if (r)
            q <= 1'b0;
        else if (g)
            q <= d;
endmodule

module my_latchr_n (
    input  wire d, g, r,
    output reg  q
);
    always @(*)
        if (!r)
            q <= 1'b0;
        else if (g)
            q <= d;
endmodule


module my_latchns_p (
    input  wire d, g, s,
    output reg  q
);
    always @(*)
        if (s)
            q <= 1'b1;
        else if (!g)
            q <= d;
endmodule

module my_latchns_n (
    input  wire d, g, s,
    output reg  q
);
    always @(*)
        if (!s)
            q <= 1'b1;
        else if (!g)
            q <= d;
endmodule

module my_latchnr_p (
    input  wire d, g, r,
    output reg  q
);
    always @(*)
        if (r)
            q <= 1'b0;
        else if (!g)
            q <= d;
endmodule

module my_latchnr_n (
    input  wire d, g, r,
    output reg  q
);
    always @(*)
        if (!r)
            q <= 1'b0;
        else if (!g)
            q <= d;
endmodule

