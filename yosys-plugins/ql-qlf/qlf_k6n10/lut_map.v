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

`ifndef NO_LUT
module \$lut (A, Y);
    parameter WIDTH = 0;
    parameter LUT = 0;

    (* force_downto *)
    input [WIDTH-1:0] A;
    output Y;

    generate
	    if (WIDTH == 6) begin
	       frac_lut6 #(.LUT(LUT)) _TECHMAP_REPLACE_ (.lut6_out(Y),.in(A));

	    end else begin
	       wire _TECHMAP_FAIL_ = 1;
	    end
    endgenerate

endmodule
`endif



