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

module mux2 (
    S,
    A,
    B,
    Y
);
  input S;
  input A, B;
  output reg Y;

  always @(*) Y = (S) ? B : A;
endmodule

module mux4 (
    S,
    D,
    Y
);
  input [1:0] S;
  input [3:0] D;
  output Y;

  reg Y;
  wire [1:0] S;
  wire [3:0] D;

  always @* begin
    case (S)
      0: Y = D[0];
      1: Y = D[1];
      2: Y = D[2];
      3: Y = D[3];
    endcase
  end
endmodule

module mux8 (
    S,
    D,
    Y
);
  input [2:0] S;
  input [7:0] D;
  output Y;

  reg Y;
  wire [2:0] S;
  wire [7:0] D;

  always @* begin
    case (S)
      0: Y = D[0];
      1: Y = D[1];
      2: Y = D[2];
      3: Y = D[3];
      4: Y = D[4];
      5: Y = D[5];
      6: Y = D[6];
      7: Y = D[7];
    endcase
  end
endmodule

module mux16 (
    D,
    S,
    Y
);
  input [15:0] D;
  input [3:0] S;
  output Y;

  assign Y = D[S];
endmodule

