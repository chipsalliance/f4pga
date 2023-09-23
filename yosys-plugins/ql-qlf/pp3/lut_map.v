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

module \$lut (
    A,
    Y
);
  parameter WIDTH = 0;
  parameter LUT = 0;

  input [WIDTH-1:0] A;
  output Y;

  generate
    if (WIDTH == 1) begin
      LUT1 #(
          .EQN (""),
          .INIT(LUT)
      ) _TECHMAP_REPLACE_ (
          .O (Y),
          .I0(A[0])
      );
    end else if (WIDTH == 2) begin
      LUT2 #(
          .EQN (""),
          .INIT(LUT)
      ) _TECHMAP_REPLACE_ (
          .O (Y),
          .I0(A[0]),
          .I1(A[1])
      );
    end else if (WIDTH == 3) begin
      LUT3 #(
          .EQN (""),
          .INIT(LUT)
      ) _TECHMAP_REPLACE_ (
          .O (Y),
          .I0(A[0]),
          .I1(A[1]),
          .I2(A[2])
      );
    end else if (WIDTH == 4) begin
      LUT4 #(
          .EQN (""),
          .INIT(LUT)
      ) _TECHMAP_REPLACE_ (
          .O (Y),
          .I0(A[0]),
          .I1(A[1]),
          .I2(A[2]),
          .I3(A[3])
      );
    end else begin
      wire _TECHMAP_FAIL_ = 1;
    end
  endgenerate
endmodule
