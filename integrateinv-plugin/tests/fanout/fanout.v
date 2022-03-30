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

(* blackbox *)
module box(
    (* invertible_pin="INV_A" *)
    input  wire A,
    input  wire B,

    output wire Y
);

    parameter [0:0] INV_A = 1'b0;

endmodule


module top(
    input  wire [1:0] di,
    output wire [5:0] do
);

    wire [1:0] d;

    \$_NOT_ n0 (.A(di[0]), .Y(d[0]));

    box b00 (.A(d[0]), .B(    ), .Y(do[0]));
    box b01 (.A(d[0]), .B(    ), .Y(do[1]));
    box b02 (.A(    ), .B(d[0]), .Y(do[2]));

    \$_NOT_ n1 (.A(di[1]), .Y(d[1]));

    box b10 (.A(d[1]), .B(    ), .Y(do[3]));
    box b11 (.A(d[1]), .B(    ), .Y(do[4]));
    box b12 (.A(d[1]), .B(    ), .Y(do[5]));

endmodule
