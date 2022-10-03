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

module mult_16x16 (
    input  wire [15:0] A,
    input  wire [15:0] B,
    output wire [31:0] Z
);

    assign Z = A * B;

endmodule

module mult_20x18 (
    input  wire [19:0] A,
    input  wire [17:0] B,
    output wire [37:0] Z
);

    assign Z = A * B;

endmodule

module mult_8x8 (
    input  wire [ 7:0] A,
    input  wire [ 7:0] B,
    output wire [15:0] Z
);

    assign Z = A * B;

endmodule

module mult_10x9 (
    input  wire [ 9:0] A,
    input  wire [ 8:0] B,
    output wire [18:0] Z
);

    assign Z = A * B;

endmodule

module mult_8x8_s (
    input  wire signed [ 7:0] A,
    input  wire signed [ 7:0] B,
    output wire signed [15:0] Z
);

    assign Z = A * B;

endmodule
