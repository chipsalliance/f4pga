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
    input  wire [1:0] A,
    input  wire [1:0] B,

    output wire Y
);

    parameter [1:0] INV_A = 2'b00;

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

    box #(.INV_A(2'b01)) the_box (
        .A ({d[1], d[0]}),
        .B ({d[3], d[2]}),

        .Y (do)
    );

endmodule
