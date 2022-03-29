// Copyright (C) 2019-2022 The SymbiFlow Authors
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier: ISC
(* techmap_celltype = "$alu" *)
module _80_quicklogic_alu (A, B, CI, BI, X, Y, CO);
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 2;
	parameter B_WIDTH = 2;
	parameter Y_WIDTH = 2;
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
	wire co;

	(* force_downto *)
	//wire [Y_WIDTH-1:0] C = {CO, CI};
	wire [Y_WIDTH:0] C;
	(* force_downto *)
	wire [Y_WIDTH-1:0] S  = {AA ^ BB};
	assign CO[Y_WIDTH-1:0] = C[Y_WIDTH:1];
        //assign CO[Y_WIDTH-1] = co;

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
	generate if (Y_WIDTH > 2) begin
	  for (i = 0; i < Y_WIDTH-2; i = i + 1) begin:slice
		adder_carry  my_adder (
			.cin(C[i]),
			.g(AA[i]),
			.p(S[i]),
			.cout(C[i+1]),
		        .sumout(Y[i])
		);
	      end
	end endgenerate
	generate
	     adder_carry final_adder (
	       .cin     (C[Y_WIDTH-2]),
	       .cout    (),
	       .p       (1'b0),
	       .g       (1'b0),
	       .sumout    (co)
	     );
	endgenerate

	assign Y[Y_WIDTH-2] = S[Y_WIDTH-2] ^ co;
        assign C[Y_WIDTH-1] = S[Y_WIDTH-2] ? co : AA[Y_WIDTH-2];
	assign Y[Y_WIDTH-1] = S[Y_WIDTH-1] ^ C[Y_WIDTH-1];
        assign C[Y_WIDTH] = S[Y_WIDTH-1] ? C[Y_WIDTH-1] : AA[Y_WIDTH-1];

	assign X = S;
endmodule

