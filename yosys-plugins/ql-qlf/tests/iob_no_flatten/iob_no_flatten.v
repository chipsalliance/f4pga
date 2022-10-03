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

module my_top (
    inout  wire pad,
    input  wire i,
    input  wire t,
    output wire o,
    input  wire clk
);

  wire i_r;
  wire t_r;
  wire o_r;

  // IOB
  assign pad = (t_r) ? i_r : 1'bz;
  assign o_r = pad;

  // DFFs
  my_dff dff_i (
      i,
      clk,
      i_r
  );
  my_dff dff_t (
      t,
      clk,
      t_r
  );
  my_dff dff_o (
      o_r,
      clk,
      o
  );

endmodule
