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

(* keep_hierarchy *)
module my_lut (
    input  wire [3:0] i,
    output wire       o
);

  LUT4 #(
      .INIT(16'hAAAA)
  ) my_lut (
      .I0(i[0]),
      .I1(i[1]),
      .I2(i[2]),
      .I3(1'bx),
      .O (o)
  );

endmodule

module my_top (
    input  wire i,
    output wire o
);

  my_lut my_lut (
      .i({1'b0, 1'b1, i}),
      .o(o)
  );

endmodule
