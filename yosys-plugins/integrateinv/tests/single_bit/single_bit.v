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
    (* invertible_pin="INV_C" *)
    input  wire C,
    input  wire D,

    output wire Y
);

    parameter [0:0] INV_A = 1'b0;
    parameter [0:0] INV_C = 1'b0;

endmodule


module top(
    input  wire [3:0] di,
    output wire       do
);

    wire [3:0] d;

    \$_NOT_ n0 (.A(di[0]), .Y(d[0]));
    \$_NOT_ n1 (.A(di[1]), .Y(d[1]));
    \$_NOT_ n2 (.A(di[2]), .Y(d[2]));
    \$_NOT_ n3 (.A(di[3]), .Y(d[3]));

    box #(.INV_A(1'b1)) the_box (
        .A (d[0]),
        .B (d[1]),
        .C (d[2]),
        .D (d[3]),

        .Y (do)
    );

endmodule
