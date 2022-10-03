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

module latchp (
    input d,
    clk,
    en,
    output reg q
);
  initial q <= 1'b0;
  always @* if (en) q <= d;
endmodule

module latchn (
    input d,
    clk,
    en,
    output reg q
);
  always @* if (!en) q <= d;
endmodule

module my_latchsre (
    input d,
    clk,
    en,
    clr,
    pre,
    output reg q
);
  always @*
    if (clr) q <= 1'b0;
    else if (pre) q <= 1'b1;
    else if (en) q <= d;
endmodule

module latchp_noinit (
    input d,
    clk,
    en,
    output reg q
);
  always @* if (en) q <= d;
endmodule
