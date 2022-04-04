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

module \$__MUL16X16 (input [15:0] A, input [15:0] B, output [31:0] Y);
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 0;
	parameter B_WIDTH = 0;
	parameter Y_WIDTH = 0;

	QL_DSP #(
		.A_REG(1'b0),
		.B_REG(1'b0),
		.C_REG(1'b0),
		.D_REG(1'b0),
		.ENABLE_DSP(1'b1),
	) _TECHMAP_REPLACE_ (
		.A(A),
		.B(B),
		.O(Y),
	);
endmodule
