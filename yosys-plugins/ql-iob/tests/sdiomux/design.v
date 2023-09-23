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

module top (
    input  wire       clk,
    output wire [3:0] led,
    inout  wire       io
);

  reg [3:0] r;
  initial r <= 0;

  always @(posedge clk) r <= r + io;

  assign led = {r[0], r[1], r[2], r[3]};
  assign io  = r[0] ? 1 : 1'bz;

endmodule
