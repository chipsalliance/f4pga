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

module my_gate (
    input  wire A,
    output wire Y
);

    assign Y = ~A;
endmodule

module top (
    input  wire [7:0] di,
    output wire [7:0] do
);

    my_gate c0 (.A(di[0]), .Y(do[0]));
    \$_BUF_ c1 (.A(di[1]), .Y(do[1]));
    \$_BUF_ c2 (.A(di[2]), .Y(do[2]));
    \$_BUF_ c3 (.A(di[3]), .Y(do[3]));
    \$_BUF_ c4 (.A(di[4]), .Y(do[4]));
    \$_NOT_ c5 (.A(di[5]), .Y(do[5]));
    \$_NOT_ c6 (.A(di[6]), .Y(do[6]));
    \$_NOT_ c7 (.A(di[7]), .Y(do[7]));

endmodule
