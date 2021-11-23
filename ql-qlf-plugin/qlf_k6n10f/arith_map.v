// Copyright (C) 2020-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier:ISC
(* techmap_celltype = "$alu" *)
module _80_quicklogic_alu (A, B, CI, BI, X, Y, CO);
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;
	parameter _TECHMAP_CONSTVAL_CI_ = 0;
	parameter _TECHMAP_CONSTMSK_CI_ = 0;

	(* force_downto *)
	input [A_WIDTH-1:0] A;
	(* force_downto *)
	input [B_WIDTH-1:0] B;
	(* force_downto *)
	output [Y_WIDTH-1:0] X, Y;

	input CI, BI;
	(* force_downto *)
	output [Y_WIDTH-1:0] CO;

	wire _TECHMAP_FAIL_ = Y_WIDTH <= 2;

	(* force_downto *)
	wire [Y_WIDTH-1:0] A_buf, B_buf;
	\$pos #(.A_SIGNED(A_SIGNED), .A_WIDTH(A_WIDTH), .Y_WIDTH(Y_WIDTH)) A_conv (.A(A), .Y(A_buf));
	\$pos #(.A_SIGNED(B_SIGNED), .A_WIDTH(B_WIDTH), .Y_WIDTH(Y_WIDTH)) B_conv (.A(B), .Y(B_buf));

	(* force_downto *)
	wire [Y_WIDTH-1:0] AA = A_buf;
	(* force_downto *)
	wire [Y_WIDTH-1:0] BB = BI ? ~B_buf : B_buf;

	genvar i;

	(* force_downto *)
	//wire [Y_WIDTH-1:0] C = {CO, CI};
	wire [Y_WIDTH:0] C;
	(* force_downto *)
	wire [Y_WIDTH-1:0] S  = {AA ^ BB};

	generate
	     adder_carry intermediate_adder (
	       .cin     ( ),
	       .cout    (C[0]),
	       .p       (1'b0),
	       .g       (CI),
	       .sumout    ()
	     );
	endgenerate
	genvar i;
	generate for (i = 0; i < Y_WIDTH; i = i + 1) begin:slice
		adder_carry  my_adder (
			.cin(C[i]),
			.g(AA[i]),
			.p(S[i]),
			.cout(C[i+1]),
		        .sumout(Y[i])
		);
	end endgenerate
	assign X = S;
endmodule

