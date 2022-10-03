// Copyright (C) 2019-2022 The SymbiFlow Authors
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier: ISC

module BRAM_TDP_SPLIT #(parameter AWIDTH = 9,
parameter DWIDTH = 32)(
	clk_a,
	rce_a,
	ra_a,
	rq_a,
	wce_a,
	wa_a,
	wd_a,

	clk_b,
	rce_b,
	ra_b,
	rq_b,
	wce_b,
	wa_b,
	wd_b
);

	input			clk_a;
	input                   rce_a;
	input      [AWIDTH-1:0] ra_a;
	output reg [DWIDTH-1:0] rq_a;
	input                   wce_a;
	input      [AWIDTH-1:0] wa_a;
	input      [DWIDTH-1:0] wd_a;

	input			clk_b;
	input                   rce_b;
	input      [AWIDTH-1:0] ra_b;
	output reg [DWIDTH-1:0] rq_b;
	input                   wce_b;
	input      [AWIDTH-1:0] wa_b;
	input      [DWIDTH-1:0] wd_b;

	reg        [DWIDTH-1:0] memory[0:(1<<AWIDTH)-1];

	always @(posedge clk_a) begin
		if (rce_a)
			rq_a <= memory[ra_a];

		if (wce_a)
			memory[wa_a] <= wd_a;
	end

	always @(posedge clk_b) begin
		if (rce_b)
			rq_b <= memory[ra_b];

		if (wce_b)
			memory[wa_b] <= wd_b;
	end

	integer i;
	initial
	begin
		for(i = 0; i < (1<<AWIDTH)-1; i = i + 1)
			memory[i] = 0;
	end

endmodule

module BRAM_TDP_SPLIT_2x18K #(parameter AWIDTH = 10, parameter DWIDTH = 18)(
	clk_a_0,
	rce_a_0,
	ra_a_0,
	rq_a_0,
	wce_a_0,
	wa_a_0,
	wd_a_0,

	clk_a_1,
	rce_a_1,
	ra_a_1,
	rq_a_1,
	wce_a_1,
	wa_a_1,
	wd_a_1,

	clk_b_0,
	rce_b_0,
	ra_b_0,
	rq_b_0,
	wce_b_0,
	wa_b_0,
	wd_b_0,

	clk_b_1,
	rce_b_1,
	ra_b_1,
	rq_b_1,
	wce_b_1,
	wa_b_1,
	wd_b_1
);

	input			clk_a_0;
	input                   rce_a_0;
	input      [AWIDTH-1:0] ra_a_0;
	output     [DWIDTH-1:0] rq_a_0;
	input                   wce_a_0;
	input      [AWIDTH-1:0] wa_a_0;
	input      [DWIDTH-1:0] wd_a_0;
	input			clk_b_0;
	input                   rce_b_0;
	input      [AWIDTH-1:0] ra_b_0;
	output     [DWIDTH-1:0] rq_b_0;
	input                   wce_b_0;
	input      [AWIDTH-1:0] wa_b_0;
	input      [DWIDTH-1:0] wd_b_0;

	input			clk_a_1;
	input                   rce_a_1;
	input      [AWIDTH-1:0] ra_a_1;
	output     [DWIDTH-1:0] rq_a_1;
	input                   wce_a_1;
	input      [AWIDTH-1:0] wa_a_1;
	input      [DWIDTH-1:0] wd_a_1;
	input			clk_b_1;
	input                   rce_b_1;
	input      [AWIDTH-1:0] ra_b_1;
	output     [DWIDTH-1:0] rq_b_1;
	input                   wce_b_1;
	input      [AWIDTH-1:0] wa_b_1;
	input      [DWIDTH-1:0] wd_b_1;

BRAM_TDP_SPLIT #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_TDP_SPLIT_0 (.clk_a(clk_a_0),
		 .rce_a(rce_a_0),
		 .ra_a(ra_a_0),
		 .rq_a(rq_a_0),
		 .wce_a(wce_a_0),
		 .wa_a(wa_a_0),
		 .wd_a(wd_a_0),
		 .clk_b(clk_b_0),
		 .rce_b(rce_b_0),
		 .ra_b(ra_b_0),
		 .rq_b(rq_b_0),
		 .wce_b(wce_b_0),
		 .wa_b(wa_b_0),
		 .wd_b(wd_b_0));

BRAM_TDP_SPLIT #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_TDP_SPLIT_1 (.clk_a(clk_a_1),
		 .rce_a(rce_a_1),
		 .ra_a(ra_a_1),
		 .rq_a(rq_a_1),
		 .wce_a(wce_a_1),
		 .wa_a(wa_a_1),
		 .wd_a(wd_a_1),
		 .clk_b(clk_b_1),
		 .rce_b(rce_b_1),
		 .ra_b(ra_b_1),
		 .rq_b(rq_b_1),
		 .wce_b(wce_b_1),
		 .wa_b(wa_b_1),
		 .wd_b(wd_b_1));
endmodule


module BRAM_TDP_SPLIT_2x18x1024 (
	clk_a_0,
	rce_a_0,
	ra_a_0,
	rq_a_0,
	wce_a_0,
	wa_a_0,
	wd_a_0,

	clk_a_1,
	rce_a_1,
	ra_a_1,
	rq_a_1,
	wce_a_1,
	wa_a_1,
	wd_a_1,

	clk_b_0,
	rce_b_0,
	ra_b_0,
	rq_b_0,
	wce_b_0,
	wa_b_0,
	wd_b_0,

	clk_b_1,
	rce_b_1,
	ra_b_1,
	rq_b_1,
	wce_b_1,
	wa_b_1,
	wd_b_1
);

parameter AWIDTH = 10;
parameter DWIDTH = 18;

	input			clk_a_0;
	input                   rce_a_0;
	input      [AWIDTH-1:0] ra_a_0;
	output     [DWIDTH-1:0] rq_a_0;
	input                   wce_a_0;
	input      [AWIDTH-1:0] wa_a_0;
	input      [DWIDTH-1:0] wd_a_0;
	input			clk_b_0;
	input                   rce_b_0;
	input      [AWIDTH-1:0] ra_b_0;
	output     [DWIDTH-1:0] rq_b_0;
	input                   wce_b_0;
	input      [AWIDTH-1:0] wa_b_0;
	input      [DWIDTH-1:0] wd_b_0;

	input			clk_a_1;
	input                   rce_a_1;
	input      [AWIDTH-1:0] ra_a_1;
	output     [DWIDTH-1:0] rq_a_1;
	input                   wce_a_1;
	input      [AWIDTH-1:0] wa_a_1;
	input      [DWIDTH-1:0] wd_a_1;
	input			clk_b_1;
	input                   rce_b_1;
	input      [AWIDTH-1:0] ra_b_1;
	output     [DWIDTH-1:0] rq_b_1;
	input                   wce_b_1;
	input      [AWIDTH-1:0] wa_b_1;
	input      [DWIDTH-1:0] wd_b_1;

BRAM_TDP_SPLIT_2x18K #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_TDP_SPLIT_2x18x1024 (
		 .clk_a_0(clk_a_0),
		 .rce_a_0(rce_a_0),
		 .ra_a_0(ra_a_0),
		 .rq_a_0(rq_a_0),
		 .wce_a_0(wce_a_0),
		 .wa_a_0(wa_a_0),
		 .wd_a_0(wd_a_0),
		 .clk_b_0(clk_b_0),
		 .rce_b_0(rce_b_0),
		 .ra_b_0(ra_b_0),
		 .rq_b_0(rq_b_0),
		 .wce_b_0(wce_b_0),
		 .wa_b_0(wa_b_0),
		 .wd_b_0(wd_b_0),
		 .clk_a_1(clk_a_1),
		 .rce_a_1(rce_a_1),
		 .ra_a_1(ra_a_1),
		 .rq_a_1(rq_a_1),
		 .wce_a_1(wce_a_1),
		 .wa_a_1(wa_a_1),
		 .wd_a_1(wd_a_1),
		 .clk_b_1(clk_b_1),
		 .rce_b_1(rce_b_1),
		 .ra_b_1(ra_b_1),
		 .rq_b_1(rq_b_1),
		 .wce_b_1(wce_b_1),
		 .wa_b_1(wa_b_1),
		 .wd_b_1(wd_b_1));
endmodule


module BRAM_TDP_SPLIT_2x16x1024 (
	clk_a_0,
	rce_a_0,
	ra_a_0,
	rq_a_0,
	wce_a_0,
	wa_a_0,
	wd_a_0,

	clk_a_1,
	rce_a_1,
	ra_a_1,
	rq_a_1,
	wce_a_1,
	wa_a_1,
	wd_a_1,

	clk_b_0,
	rce_b_0,
	ra_b_0,
	rq_b_0,
	wce_b_0,
	wa_b_0,
	wd_b_0,

	clk_b_1,
	rce_b_1,
	ra_b_1,
	rq_b_1,
	wce_b_1,
	wa_b_1,
	wd_b_1
);

parameter AWIDTH = 10;
parameter DWIDTH = 16;

	input			clk_a_0;
	input                   rce_a_0;
	input      [AWIDTH-1:0] ra_a_0;
	output     [DWIDTH-1:0] rq_a_0;
	input                   wce_a_0;
	input      [AWIDTH-1:0] wa_a_0;
	input      [DWIDTH-1:0] wd_a_0;
	input			clk_b_0;
	input                   rce_b_0;
	input      [AWIDTH-1:0] ra_b_0;
	output     [DWIDTH-1:0] rq_b_0;
	input                   wce_b_0;
	input      [AWIDTH-1:0] wa_b_0;
	input      [DWIDTH-1:0] wd_b_0;

	input			clk_a_1;
	input                   rce_a_1;
	input      [AWIDTH-1:0] ra_a_1;
	output     [DWIDTH-1:0] rq_a_1;
	input                   wce_a_1;
	input      [AWIDTH-1:0] wa_a_1;
	input      [DWIDTH-1:0] wd_a_1;
	input			clk_b_1;
	input                   rce_b_1;
	input      [AWIDTH-1:0] ra_b_1;
	output     [DWIDTH-1:0] rq_b_1;
	input                   wce_b_1;
	input      [AWIDTH-1:0] wa_b_1;
	input      [DWIDTH-1:0] wd_b_1;

BRAM_TDP_SPLIT_2x18K #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_TDP_SPLIT_2x16x1024 (
		 .clk_a_0(clk_a_0),
		 .rce_a_0(rce_a_0),
		 .ra_a_0(ra_a_0),
		 .rq_a_0(rq_a_0),
		 .wce_a_0(wce_a_0),
		 .wa_a_0(wa_a_0),
		 .wd_a_0(wd_a_0),
		 .clk_b_0(clk_b_0),
		 .rce_b_0(rce_b_0),
		 .ra_b_0(ra_b_0),
		 .rq_b_0(rq_b_0),
		 .wce_b_0(wce_b_0),
		 .wa_b_0(wa_b_0),
		 .wd_b_0(wd_b_0),
		 .clk_a_1(clk_a_1),
		 .rce_a_1(rce_a_1),
		 .ra_a_1(ra_a_1),
		 .rq_a_1(rq_a_1),
		 .wce_a_1(wce_a_1),
		 .wa_a_1(wa_a_1),
		 .wd_a_1(wd_a_1),
		 .clk_b_1(clk_b_1),
		 .rce_b_1(rce_b_1),
		 .ra_b_1(ra_b_1),
		 .rq_b_1(rq_b_1),
		 .wce_b_1(wce_b_1),
		 .wa_b_1(wa_b_1),
		 .wd_b_1(wd_b_1));
endmodule


module BRAM_TDP_SPLIT_2x9x2048 (
	clk_a_0,
	rce_a_0,
	ra_a_0,
	rq_a_0,
	wce_a_0,
	wa_a_0,
	wd_a_0,

	clk_a_1,
	rce_a_1,
	ra_a_1,
	rq_a_1,
	wce_a_1,
	wa_a_1,
	wd_a_1,

	clk_b_0,
	rce_b_0,
	ra_b_0,
	rq_b_0,
	wce_b_0,
	wa_b_0,
	wd_b_0,

	clk_b_1,
	rce_b_1,
	ra_b_1,
	rq_b_1,
	wce_b_1,
	wa_b_1,
	wd_b_1
);

parameter AWIDTH = 11;
parameter DWIDTH = 9;

	input			clk_a_0;
	input                   rce_a_0;
	input      [AWIDTH-1:0] ra_a_0;
	output     [DWIDTH-1:0] rq_a_0;
	input                   wce_a_0;
	input      [AWIDTH-1:0] wa_a_0;
	input      [DWIDTH-1:0] wd_a_0;
	input			clk_b_0;
	input                   rce_b_0;
	input      [AWIDTH-1:0] ra_b_0;
	output     [DWIDTH-1:0] rq_b_0;
	input                   wce_b_0;
	input      [AWIDTH-1:0] wa_b_0;
	input      [DWIDTH-1:0] wd_b_0;

	input			clk_a_1;
	input                   rce_a_1;
	input      [AWIDTH-1:0] ra_a_1;
	output     [DWIDTH-1:0] rq_a_1;
	input                   wce_a_1;
	input      [AWIDTH-1:0] wa_a_1;
	input      [DWIDTH-1:0] wd_a_1;
	input			clk_b_1;
	input                   rce_b_1;
	input      [AWIDTH-1:0] ra_b_1;
	output     [DWIDTH-1:0] rq_b_1;
	input                   wce_b_1;
	input      [AWIDTH-1:0] wa_b_1;
	input      [DWIDTH-1:0] wd_b_1;

BRAM_TDP_SPLIT_2x18K #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_TDP_SPLIT_2x9x2048 (
		 .clk_a_0(clk_a_0),
		 .rce_a_0(rce_a_0),
		 .ra_a_0(ra_a_0),
		 .rq_a_0(rq_a_0),
		 .wce_a_0(wce_a_0),
		 .wa_a_0(wa_a_0),
		 .wd_a_0(wd_a_0),
		 .clk_b_0(clk_b_0),
		 .rce_b_0(rce_b_0),
		 .ra_b_0(ra_b_0),
		 .rq_b_0(rq_b_0),
		 .wce_b_0(wce_b_0),
		 .wa_b_0(wa_b_0),
		 .wd_b_0(wd_b_0),
		 .clk_a_1(clk_a_1),
		 .rce_a_1(rce_a_1),
		 .ra_a_1(ra_a_1),
		 .rq_a_1(rq_a_1),
		 .wce_a_1(wce_a_1),
		 .wa_a_1(wa_a_1),
		 .wd_a_1(wd_a_1),
		 .clk_b_1(clk_b_1),
		 .rce_b_1(rce_b_1),
		 .ra_b_1(ra_b_1),
		 .rq_b_1(rq_b_1),
		 .wce_b_1(wce_b_1),
		 .wa_b_1(wa_b_1),
		 .wd_b_1(wd_b_1));
endmodule

module BRAM_TDP_SPLIT_2x8x2048 (
	clk_a_0,
	rce_a_0,
	ra_a_0,
	rq_a_0,
	wce_a_0,
	wa_a_0,
	wd_a_0,

	clk_a_1,
	rce_a_1,
	ra_a_1,
	rq_a_1,
	wce_a_1,
	wa_a_1,
	wd_a_1,

	clk_b_0,
	rce_b_0,
	ra_b_0,
	rq_b_0,
	wce_b_0,
	wa_b_0,
	wd_b_0,

	clk_b_1,
	rce_b_1,
	ra_b_1,
	rq_b_1,
	wce_b_1,
	wa_b_1,
	wd_b_1
);

parameter AWIDTH = 11;
parameter DWIDTH = 8;

	input			clk_a_0;
	input                   rce_a_0;
	input      [AWIDTH-1:0] ra_a_0;
	output     [DWIDTH-1:0] rq_a_0;
	input                   wce_a_0;
	input      [AWIDTH-1:0] wa_a_0;
	input      [DWIDTH-1:0] wd_a_0;
	input			clk_b_0;
	input                   rce_b_0;
	input      [AWIDTH-1:0] ra_b_0;
	output     [DWIDTH-1:0] rq_b_0;
	input                   wce_b_0;
	input      [AWIDTH-1:0] wa_b_0;
	input      [DWIDTH-1:0] wd_b_0;

	input			clk_a_1;
	input                   rce_a_1;
	input      [AWIDTH-1:0] ra_a_1;
	output     [DWIDTH-1:0] rq_a_1;
	input                   wce_a_1;
	input      [AWIDTH-1:0] wa_a_1;
	input      [DWIDTH-1:0] wd_a_1;
	input			clk_b_1;
	input                   rce_b_1;
	input      [AWIDTH-1:0] ra_b_1;
	output     [DWIDTH-1:0] rq_b_1;
	input                   wce_b_1;
	input      [AWIDTH-1:0] wa_b_1;
	input      [DWIDTH-1:0] wd_b_1;

BRAM_TDP_SPLIT_2x18K #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_TDP_SPLIT_2x8x2048 (
		 .clk_a_0(clk_a_0),
		 .rce_a_0(rce_a_0),
		 .ra_a_0(ra_a_0),
		 .rq_a_0(rq_a_0),
		 .wce_a_0(wce_a_0),
		 .wa_a_0(wa_a_0),
		 .wd_a_0(wd_a_0),
		 .clk_b_0(clk_b_0),
		 .rce_b_0(rce_b_0),
		 .ra_b_0(ra_b_0),
		 .rq_b_0(rq_b_0),
		 .wce_b_0(wce_b_0),
		 .wa_b_0(wa_b_0),
		 .wd_b_0(wd_b_0),
		 .clk_a_1(clk_a_1),
		 .rce_a_1(rce_a_1),
		 .ra_a_1(ra_a_1),
		 .rq_a_1(rq_a_1),
		 .wce_a_1(wce_a_1),
		 .wa_a_1(wa_a_1),
		 .wd_a_1(wd_a_1),
		 .clk_b_1(clk_b_1),
		 .rce_b_1(rce_b_1),
		 .ra_b_1(ra_b_1),
		 .rq_b_1(rq_b_1),
		 .wce_b_1(wce_b_1),
		 .wa_b_1(wa_b_1),
		 .wd_b_1(wd_b_1));
endmodule

module BRAM_TDP_SPLIT_2x4x4096 (
	clk_a_0,
	rce_a_0,
	ra_a_0,
	rq_a_0,
	wce_a_0,
	wa_a_0,
	wd_a_0,

	clk_a_1,
	rce_a_1,
	ra_a_1,
	rq_a_1,
	wce_a_1,
	wa_a_1,
	wd_a_1,

	clk_b_0,
	rce_b_0,
	ra_b_0,
	rq_b_0,
	wce_b_0,
	wa_b_0,
	wd_b_0,

	clk_b_1,
	rce_b_1,
	ra_b_1,
	rq_b_1,
	wce_b_1,
	wa_b_1,
	wd_b_1
);

parameter AWIDTH = 12;
parameter DWIDTH = 4;

	input			clk_a_0;
	input                   rce_a_0;
	input      [AWIDTH-1:0] ra_a_0;
	output     [DWIDTH-1:0] rq_a_0;
	input                   wce_a_0;
	input      [AWIDTH-1:0] wa_a_0;
	input      [DWIDTH-1:0] wd_a_0;
	input			clk_b_0;
	input                   rce_b_0;
	input      [AWIDTH-1:0] ra_b_0;
	output     [DWIDTH-1:0] rq_b_0;
	input                   wce_b_0;
	input      [AWIDTH-1:0] wa_b_0;
	input      [DWIDTH-1:0] wd_b_0;

	input			clk_a_1;
	input                   rce_a_1;
	input      [AWIDTH-1:0] ra_a_1;
	output     [DWIDTH-1:0] rq_a_1;
	input                   wce_a_1;
	input      [AWIDTH-1:0] wa_a_1;
	input      [DWIDTH-1:0] wd_a_1;
	input			clk_b_1;
	input                   rce_b_1;
	input      [AWIDTH-1:0] ra_b_1;
	output     [DWIDTH-1:0] rq_b_1;
	input                   wce_b_1;
	input      [AWIDTH-1:0] wa_b_1;
	input      [DWIDTH-1:0] wd_b_1;

BRAM_TDP_SPLIT_2x18K #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_TDP_SPLIT_2x4x4096 (
		 .clk_a_0(clk_a_0),
		 .rce_a_0(rce_a_0),
		 .ra_a_0(ra_a_0),
		 .rq_a_0(rq_a_0),
		 .wce_a_0(wce_a_0),
		 .wa_a_0(wa_a_0),
		 .wd_a_0(wd_a_0),
		 .clk_b_0(clk_b_0),
		 .rce_b_0(rce_b_0),
		 .ra_b_0(ra_b_0),
		 .rq_b_0(rq_b_0),
		 .wce_b_0(wce_b_0),
		 .wa_b_0(wa_b_0),
		 .wd_b_0(wd_b_0),
		 .clk_a_1(clk_a_1),
		 .rce_a_1(rce_a_1),
		 .ra_a_1(ra_a_1),
		 .rq_a_1(rq_a_1),
		 .wce_a_1(wce_a_1),
		 .wa_a_1(wa_a_1),
		 .wd_a_1(wd_a_1),
		 .clk_b_1(clk_b_1),
		 .rce_b_1(rce_b_1),
		 .ra_b_1(ra_b_1),
		 .rq_b_1(rq_b_1),
		 .wce_b_1(wce_b_1),
		 .wa_b_1(wa_b_1),
		 .wd_b_1(wd_b_1));
endmodule

module BRAM_TDP_SPLIT_2x2x8192 (
	clk_a_0,
	rce_a_0,
	ra_a_0,
	rq_a_0,
	wce_a_0,
	wa_a_0,
	wd_a_0,

	clk_a_1,
	rce_a_1,
	ra_a_1,
	rq_a_1,
	wce_a_1,
	wa_a_1,
	wd_a_1,

	clk_b_0,
	rce_b_0,
	ra_b_0,
	rq_b_0,
	wce_b_0,
	wa_b_0,
	wd_b_0,

	clk_b_1,
	rce_b_1,
	ra_b_1,
	rq_b_1,
	wce_b_1,
	wa_b_1,
	wd_b_1
);

parameter AWIDTH = 13;
parameter DWIDTH = 2;

	input			clk_a_0;
	input                   rce_a_0;
	input      [AWIDTH-1:0] ra_a_0;
	output     [DWIDTH-1:0] rq_a_0;
	input                   wce_a_0;
	input      [AWIDTH-1:0] wa_a_0;
	input      [DWIDTH-1:0] wd_a_0;
	input			clk_b_0;
	input                   rce_b_0;
	input      [AWIDTH-1:0] ra_b_0;
	output     [DWIDTH-1:0] rq_b_0;
	input                   wce_b_0;
	input      [AWIDTH-1:0] wa_b_0;
	input      [DWIDTH-1:0] wd_b_0;

	input			clk_a_1;
	input                   rce_a_1;
	input      [AWIDTH-1:0] ra_a_1;
	output     [DWIDTH-1:0] rq_a_1;
	input                   wce_a_1;
	input      [AWIDTH-1:0] wa_a_1;
	input      [DWIDTH-1:0] wd_a_1;
	input			clk_b_1;
	input                   rce_b_1;
	input      [AWIDTH-1:0] ra_b_1;
	output     [DWIDTH-1:0] rq_b_1;
	input                   wce_b_1;
	input      [AWIDTH-1:0] wa_b_1;
	input      [DWIDTH-1:0] wd_b_1;

BRAM_TDP_SPLIT_2x18K #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_TDP_SPLIT_2x2x8192 (
		 .clk_a_0(clk_a_0),
		 .rce_a_0(rce_a_0),
		 .ra_a_0(ra_a_0),
		 .rq_a_0(rq_a_0),
		 .wce_a_0(wce_a_0),
		 .wa_a_0(wa_a_0),
		 .wd_a_0(wd_a_0),
		 .clk_b_0(clk_b_0),
		 .rce_b_0(rce_b_0),
		 .ra_b_0(ra_b_0),
		 .rq_b_0(rq_b_0),
		 .wce_b_0(wce_b_0),
		 .wa_b_0(wa_b_0),
		 .wd_b_0(wd_b_0),
		 .clk_a_1(clk_a_1),
		 .rce_a_1(rce_a_1),
		 .ra_a_1(ra_a_1),
		 .rq_a_1(rq_a_1),
		 .wce_a_1(wce_a_1),
		 .wa_a_1(wa_a_1),
		 .wd_a_1(wd_a_1),
		 .clk_b_1(clk_b_1),
		 .rce_b_1(rce_b_1),
		 .ra_b_1(ra_b_1),
		 .rq_b_1(rq_b_1),
		 .wce_b_1(wce_b_1),
		 .wa_b_1(wa_b_1),
		 .wd_b_1(wd_b_1));
endmodule

module BRAM_TDP_SPLIT_2x1x16384 (
	clk_a_0,
	rce_a_0,
	ra_a_0,
	rq_a_0,
	wce_a_0,
	wa_a_0,
	wd_a_0,

	clk_a_1,
	rce_a_1,
	ra_a_1,
	rq_a_1,
	wce_a_1,
	wa_a_1,
	wd_a_1,

	clk_b_0,
	rce_b_0,
	ra_b_0,
	rq_b_0,
	wce_b_0,
	wa_b_0,
	wd_b_0,

	clk_b_1,
	rce_b_1,
	ra_b_1,
	rq_b_1,
	wce_b_1,
	wa_b_1,
	wd_b_1
);

parameter AWIDTH = 14;
parameter DWIDTH = 1;

	input			clk_a_0;
	input                   rce_a_0;
	input      [AWIDTH-1:0] ra_a_0;
	output     [DWIDTH-1:0] rq_a_0;
	input                   wce_a_0;
	input      [AWIDTH-1:0] wa_a_0;
	input      [DWIDTH-1:0] wd_a_0;
	input			clk_b_0;
	input                   rce_b_0;
	input      [AWIDTH-1:0] ra_b_0;
	output     [DWIDTH-1:0] rq_b_0;
	input                   wce_b_0;
	input      [AWIDTH-1:0] wa_b_0;
	input      [DWIDTH-1:0] wd_b_0;

	input			clk_a_1;
	input                   rce_a_1;
	input      [AWIDTH-1:0] ra_a_1;
	output     [DWIDTH-1:0] rq_a_1;
	input                   wce_a_1;
	input      [AWIDTH-1:0] wa_a_1;
	input      [DWIDTH-1:0] wd_a_1;
	input			clk_b_1;
	input                   rce_b_1;
	input      [AWIDTH-1:0] ra_b_1;
	output     [DWIDTH-1:0] rq_b_1;
	input                   wce_b_1;
	input      [AWIDTH-1:0] wa_b_1;
	input      [DWIDTH-1:0] wd_b_1;

BRAM_TDP_SPLIT_2x18K #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_TDP_SPLIT_2x1x16384 (
		 .clk_a_0(clk_a_0),
		 .rce_a_0(rce_a_0),
		 .ra_a_0(ra_a_0),
		 .rq_a_0(rq_a_0),
		 .wce_a_0(wce_a_0),
		 .wa_a_0(wa_a_0),
		 .wd_a_0(wd_a_0),
		 .clk_b_0(clk_b_0),
		 .rce_b_0(rce_b_0),
		 .ra_b_0(ra_b_0),
		 .rq_b_0(rq_b_0),
		 .wce_b_0(wce_b_0),
		 .wa_b_0(wa_b_0),
		 .wd_b_0(wd_b_0),
		 .clk_a_1(clk_a_1),
		 .rce_a_1(rce_a_1),
		 .ra_a_1(ra_a_1),
		 .rq_a_1(rq_a_1),
		 .wce_a_1(wce_a_1),
		 .wa_a_1(wa_a_1),
		 .wd_a_1(wd_a_1),
		 .clk_b_1(clk_b_1),
		 .rce_b_1(rce_b_1),
		 .ra_b_1(ra_b_1),
		 .rq_b_1(rq_b_1),
		 .wce_b_1(wce_b_1),
		 .wa_b_1(wa_b_1),
		 .wd_b_1(wd_b_1));
endmodule

