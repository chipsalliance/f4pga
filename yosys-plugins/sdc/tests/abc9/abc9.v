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
    input  clk1,
    clk2,
    output led1,
    led2
);

  reg [15:0] counter1 = 0;
  reg [15:0] counter2 = 0;

  assign led1 = counter1[15];
  assign led2 = counter2[15];

  always @(posedge clk1) counter1 <= counter1 + 1;

  always @(posedge clk2) counter2 <= counter2 + 1;

endmodule
