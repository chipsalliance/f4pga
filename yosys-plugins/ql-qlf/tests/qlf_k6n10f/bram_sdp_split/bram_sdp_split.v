// Copyright (C) 2019-2022 The SymbiFlow Authors
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier: ISC

module BRAM_SDP_SPLIT #(parameter AWIDTH = 9,
parameter DWIDTH = 32)(
	clk,
	rce,
	ra,
	rq,
	wce,
	wa,
	wd
);

	input			clk;
	input                   rce;
	input      [AWIDTH-1:0] ra;
	output reg [DWIDTH-1:0] rq;
	input                   wce;
	input      [AWIDTH-1:0] wa;
	input      [DWIDTH-1:0] wd;

	reg        [DWIDTH-1:0] memory[0:(1<<AWIDTH)-1];

	always @(posedge clk) begin
		if (rce)
			rq <= memory[ra];

		if (wce)
			memory[wa] <= wd;
	end

	integer i;
	initial
	begin
		for(i = 0; i < (1<<AWIDTH)-1; i = i + 1)
			memory[i] = 0;
	end

endmodule

module BRAM_SDP_SPLIT_2x18K #(parameter AWIDTH = 10, parameter DWIDTH = 18)(
	clk_0,
	rce_0,
	ra_0,
	rq_0,
	wce_0,
	wa_0,
	wd_0,

	clk_1,
	rce_1,
	ra_1,
	rq_1,
	wce_1,
	wa_1,
	wd_1
);

	input			clk_0;
	input                   rce_0;
	input      [AWIDTH-1:0] ra_0;
	output     [DWIDTH-1:0] rq_0;
	input                   wce_0;
	input      [AWIDTH-1:0] wa_0;
	input      [DWIDTH-1:0] wd_0;
	input			clk_1;
	input                   rce_1;
	input      [AWIDTH-1:0] ra_1;
	output     [DWIDTH-1:0] rq_1;
	input                   wce_1;
	input      [AWIDTH-1:0] wa_1;
	input      [DWIDTH-1:0] wd_1;

BRAM_SDP_SPLIT #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_SDP_SPLIT_0 (.clk(clk_0),
		 .rce(rce_0),
		 .ra(ra_0),
		 .rq(rq_0),
		 .wce(wce_0),
		 .wa(wa_0),
		 .wd(wd_0));

BRAM_SDP_SPLIT #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_SDP_SPLIT_1 (.clk(clk_1),
		 .rce(rce_1),
		 .ra(ra_1),
		 .rq(rq_1),
		 .wce(wce_1),
		 .wa(wa_1),
		 .wd(wd_1));
endmodule


module BRAM_SDP_SPLIT_2x18x1024 (
	clk_0,
	rce_0,
	ra_0,
	rq_0,
	wce_0,
	wa_0,
	wd_0,

	clk_1,
	rce_1,
	ra_1,
	rq_1,
	wce_1,
	wa_1,
	wd_1
);

parameter AWIDTH = 10;
parameter DWIDTH = 18;

	input			clk_0;
	input                   rce_0;
	input      [AWIDTH-1:0] ra_0;
	output     [DWIDTH-1:0] rq_0;
	input                   wce_0;
	input      [AWIDTH-1:0] wa_0;
	input      [DWIDTH-1:0] wd_0;
	input			clk_1;
	input                   rce_1;
	input      [AWIDTH-1:0] ra_1;
	output     [DWIDTH-1:0] rq_1;
	input                   wce_1;
	input      [AWIDTH-1:0] wa_1;
	input      [DWIDTH-1:0] wd_1;

BRAM_SDP_SPLIT_2x18K #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_SDP_SPLIT_2x18x1024 (
		 .clk_0(clk_0),
		 .rce_0(rce_0),
		 .ra_0(ra_0),
		 .rq_0(rq_0),
		 .wce_0(wce_0),
		 .wa_0(wa_0),
		 .wd_0(wd_0),
		 .clk_1(clk_1),
		 .rce_1(rce_1),
		 .ra_1(ra_1),
		 .rq_1(rq_1),
		 .wce_1(wce_1),
		 .wa_1(wa_1),
		 .wd_1(wd_1));
endmodule


module BRAM_SDP_SPLIT_2x16x1024 (
	clk_0,
	rce_0,
	ra_0,
	rq_0,
	wce_0,
	wa_0,
	wd_0,

	clk_1,
	rce_1,
	ra_1,
	rq_1,
	wce_1,
	wa_1,
	wd_1
);

parameter AWIDTH = 10;
parameter DWIDTH = 16;

	input			clk_0;
	input                   rce_0;
	input      [AWIDTH-1:0] ra_0;
	output     [DWIDTH-1:0] rq_0;
	input                   wce_0;
	input      [AWIDTH-1:0] wa_0;
	input      [DWIDTH-1:0] wd_0;
	input			clk_1;
	input                   rce_1;
	input      [AWIDTH-1:0] ra_1;
	output     [DWIDTH-1:0] rq_1;
	input                   wce_1;
	input      [AWIDTH-1:0] wa_1;
	input      [DWIDTH-1:0] wd_1;

BRAM_SDP_SPLIT_2x18K #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_SDP_SPLIT_2x16x1024 (
		 .clk_0(clk_0),
		 .rce_0(rce_0),
		 .ra_0(ra_0),
		 .rq_0(rq_0),
		 .wce_0(wce_0),
		 .wa_0(wa_0),
		 .wd_0(wd_0),
		 .clk_1(clk_1),
		 .rce_1(rce_1),
		 .ra_1(ra_1),
		 .rq_1(rq_1),
		 .wce_1(wce_1),
		 .wa_1(wa_1),
		 .wd_1(wd_1));
endmodule


module BRAM_SDP_SPLIT_2x9x2048 (
	clk_0,
	rce_0,
	ra_0,
	rq_0,
	wce_0,
	wa_0,
	wd_0,

	clk_1,
	rce_1,
	ra_1,
	rq_1,
	wce_1,
	wa_1,
	wd_1
);

parameter AWIDTH = 11;
parameter DWIDTH = 9;

	input			clk_0;
	input                   rce_0;
	input      [AWIDTH-1:0] ra_0;
	output     [DWIDTH-1:0] rq_0;
	input                   wce_0;
	input      [AWIDTH-1:0] wa_0;
	input      [DWIDTH-1:0] wd_0;
	input			clk_1;
	input                   rce_1;
	input      [AWIDTH-1:0] ra_1;
	output     [DWIDTH-1:0] rq_1;
	input                   wce_1;
	input      [AWIDTH-1:0] wa_1;
	input      [DWIDTH-1:0] wd_1;

BRAM_SDP_SPLIT_2x18K #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_SDP_SPLIT_2x9x2048 (
		 .clk_0(clk_0),
		 .rce_0(rce_0),
		 .ra_0(ra_0),
		 .rq_0(rq_0),
		 .wce_0(wce_0),
		 .wa_0(wa_0),
		 .wd_0(wd_0),
		 .clk_1(clk_1),
		 .rce_1(rce_1),
		 .ra_1(ra_1),
		 .rq_1(rq_1),
		 .wce_1(wce_1),
		 .wa_1(wa_1),
		 .wd_1(wd_1));
endmodule

module BRAM_SDP_SPLIT_2x8x2048 (
	clk_0,
	rce_0,
	ra_0,
	rq_0,
	wce_0,
	wa_0,
	wd_0,

	clk_1,
	rce_1,
	ra_1,
	rq_1,
	wce_1,
	wa_1,
	wd_1
);

parameter AWIDTH = 11;
parameter DWIDTH = 8;

	input			clk_0;
	input                   rce_0;
	input      [AWIDTH-1:0] ra_0;
	output     [DWIDTH-1:0] rq_0;
	input                   wce_0;
	input      [AWIDTH-1:0] wa_0;
	input      [DWIDTH-1:0] wd_0;
	input			clk_1;
	input                   rce_1;
	input      [AWIDTH-1:0] ra_1;
	output     [DWIDTH-1:0] rq_1;
	input                   wce_1;
	input      [AWIDTH-1:0] wa_1;
	input      [DWIDTH-1:0] wd_1;

BRAM_SDP_SPLIT_2x18K #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_SDP_SPLIT_2x8x2048 (
		 .clk_0(clk_0),
		 .rce_0(rce_0),
		 .ra_0(ra_0),
		 .rq_0(rq_0),
		 .wce_0(wce_0),
		 .wa_0(wa_0),
		 .wd_0(wd_0),
		 .clk_1(clk_1),
		 .rce_1(rce_1),
		 .ra_1(ra_1),
		 .rq_1(rq_1),
		 .wce_1(wce_1),
		 .wa_1(wa_1),
		 .wd_1(wd_1));
endmodule

module BRAM_SDP_SPLIT_2x4x4096 (
	clk_0,
	rce_0,
	ra_0,
	rq_0,
	wce_0,
	wa_0,
	wd_0,

	clk_1,
	rce_1,
	ra_1,
	rq_1,
	wce_1,
	wa_1,
	wd_1
);

parameter AWIDTH = 12;
parameter DWIDTH = 4;

	input			clk_0;
	input                   rce_0;
	input      [AWIDTH-1:0] ra_0;
	output     [DWIDTH-1:0] rq_0;
	input                   wce_0;
	input      [AWIDTH-1:0] wa_0;
	input      [DWIDTH-1:0] wd_0;
	input			clk_1;
	input                   rce_1;
	input      [AWIDTH-1:0] ra_1;
	output     [DWIDTH-1:0] rq_1;
	input                   wce_1;
	input      [AWIDTH-1:0] wa_1;
	input      [DWIDTH-1:0] wd_1;

BRAM_SDP_SPLIT_2x18K #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_SDP_SPLIT_2x4x4096 (
		 .clk_0(clk_0),
		 .rce_0(rce_0),
		 .ra_0(ra_0),
		 .rq_0(rq_0),
		 .wce_0(wce_0),
		 .wa_0(wa_0),
		 .wd_0(wd_0),
		 .clk_1(clk_1),
		 .rce_1(rce_1),
		 .ra_1(ra_1),
		 .rq_1(rq_1),
		 .wce_1(wce_1),
		 .wa_1(wa_1),
		 .wd_1(wd_1));
endmodule

module BRAM_SDP_SPLIT_2x2x8192 (
	clk_0,
	rce_0,
	ra_0,
	rq_0,
	wce_0,
	wa_0,
	wd_0,

	clk_1,
	rce_1,
	ra_1,
	rq_1,
	wce_1,
	wa_1,
	wd_1
);

parameter AWIDTH = 13;
parameter DWIDTH = 2;

	input			clk_0;
	input                   rce_0;
	input      [AWIDTH-1:0] ra_0;
	output     [DWIDTH-1:0] rq_0;
	input                   wce_0;
	input      [AWIDTH-1:0] wa_0;
	input      [DWIDTH-1:0] wd_0;
	input			clk_1;
	input                   rce_1;
	input      [AWIDTH-1:0] ra_1;
	output     [DWIDTH-1:0] rq_1;
	input                   wce_1;
	input      [AWIDTH-1:0] wa_1;
	input      [DWIDTH-1:0] wd_1;

BRAM_SDP_SPLIT_2x18K #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_SDP_SPLIT_2x2x8192 (
		 .clk_0(clk_0),
		 .rce_0(rce_0),
		 .ra_0(ra_0),
		 .rq_0(rq_0),
		 .wce_0(wce_0),
		 .wa_0(wa_0),
		 .wd_0(wd_0),
		 .clk_1(clk_1),
		 .rce_1(rce_1),
		 .ra_1(ra_1),
		 .rq_1(rq_1),
		 .wce_1(wce_1),
		 .wa_1(wa_1),
		 .wd_1(wd_1));
endmodule

module BRAM_SDP_SPLIT_2x1x16384 (
	clk_0,
	rce_0,
	ra_0,
	rq_0,
	wce_0,
	wa_0,
	wd_0,

	clk_1,
	rce_1,
	ra_1,
	rq_1,
	wce_1,
	wa_1,
	wd_1
);

parameter AWIDTH = 14;
parameter DWIDTH = 1;

	input			clk_0;
	input                   rce_0;
	input      [AWIDTH-1:0] ra_0;
	output     [DWIDTH-1:0] rq_0;
	input                   wce_0;
	input      [AWIDTH-1:0] wa_0;
	input      [DWIDTH-1:0] wd_0;
	input			clk_1;
	input                   rce_1;
	input      [AWIDTH-1:0] ra_1;
	output     [DWIDTH-1:0] rq_1;
	input                   wce_1;
	input      [AWIDTH-1:0] wa_1;
	input      [DWIDTH-1:0] wd_1;

BRAM_SDP_SPLIT_2x18K #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_SDP_SPLIT_2x1x16384 (
		 .clk_0(clk_0),
		 .rce_0(rce_0),
		 .ra_0(ra_0),
		 .rq_0(rq_0),
		 .wce_0(wce_0),
		 .wa_0(wa_0),
		 .wd_0(wd_0),
		 .clk_1(clk_1),
		 .rce_1(rce_1),
		 .ra_1(ra_1),
		 .rq_1(rq_1),
		 .wce_1(wce_1),
		 .wa_1(wa_1),
		 .wd_1(wd_1));
endmodule

