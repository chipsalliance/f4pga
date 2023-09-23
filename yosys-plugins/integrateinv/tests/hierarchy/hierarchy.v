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
    output wire Y
);

    parameter [0:0] INV_A = 1'b0;

endmodule

(* keep_hierarchy *)
module child (
    input  wire       I,
    output wire [1:0] O
);

    wire d;

    \$_NOT_ n (.A(I), .Y(d));

    box b0 (.A(I), .Y(O[0]));
    box b1 (.A(d), .Y(O[1]));

endmodule


module top(
    input  wire       di,
    output wire [4:0] do
);

    wire [1:0] d;

    \$_NOT_ n0 (.A(di), .Y(d[0]));
    \$_NOT_ n1 (.A(di), .Y(d[1]));

    box   b0 (.A(d[0]), .Y(do[0]));
    box   b1 (.A(d[1]), .Y(do[1]));
    child c  (.I(d[1]), .O({do[3], do[2]}));

endmodule
