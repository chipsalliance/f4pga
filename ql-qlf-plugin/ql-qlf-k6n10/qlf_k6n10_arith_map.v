// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC

//////////////////////////
//      arithmetic      //
//////////////////////////

(* techmap_celltype = "$alu" *)
module _80_quicklogic_alu (A, B, CI, BI, X, Y, CO);

	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;

	input [A_WIDTH-1:0] A;
	input [B_WIDTH-1:0] B;
	output [Y_WIDTH:0] X, Y;

	input CI, BI;
	output [Y_WIDTH:0] CO;

	wire [Y_WIDTH-1:0] AA, BB;
	wire [1024:0] _TECHMAP_DO_ = "splitnets CARRY; clean";

	generate
		if (A_SIGNED && B_SIGNED) begin:BLOCK1
			assign AA = $signed(A), BB = BI ? ~$signed(B) : $signed(B);
		end else begin:BLOCK2
			assign AA = $unsigned(A), BB = BI ? ~$unsigned(B) : $unsigned(B);
		end
	endgenerate

	wire [Y_WIDTH: 0 ] CARRY;
	assign CARRY[0] = CI;

	genvar i;
	generate for (i = 0; i < Y_WIDTH - 1; i = i+1) begin:gen3
	     adder my_adder (
	       .cin     (CARRY[i]  ),
	       .cout    (CARRY[i+1]),
	       .a       (AA[i]     ),
	       .b       (BB[i]     ),
	       .sumout  (Y[i]      )
	     );
	end endgenerate

	generate if ((Y_WIDTH -1) % 20 == 0) begin:gen4
	     assign Y[Y_WIDTH-1] = CARRY[Y_WIDTH-1];
	end else begin:gen5
	     adder my_adder (
	       .cin     (CARRY[Y_WIDTH - 1]),
	       .cout    (CARRY[Y_WIDTH]    ),
	       .a       (1'b0              ),
	       .b       (1'b0              ),
	       .sumout  (Y[Y_WIDTH -1]     )
	     );
	end
	endgenerate
	assign X = AA ^ BB;
endmodule

