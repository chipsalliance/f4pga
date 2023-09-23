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

module BRAM_TDP #(parameter AWIDTH = 10,
parameter DWIDTH = 36)(
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

module BRAM_TDP_36x1024(
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

parameter AWIDTH = 10;
parameter DWIDTH = 36;

	input			clk_a;
	input                   rce_a;
	input      [AWIDTH-1:0] ra_a;
	output     [DWIDTH-1:0] rq_a;
	input                   wce_a;
	input      [AWIDTH-1:0] wa_a;
	input      [DWIDTH-1:0] wd_a;
	input			clk_b;
	input                   rce_b;
	input      [AWIDTH-1:0] ra_b;
	output     [DWIDTH-1:0] rq_b;
	input                   wce_b;
	input      [AWIDTH-1:0] wa_b;
	input      [DWIDTH-1:0] wd_b;

BRAM_TDP #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_TDP_36x1024 (.clk_a(clk_a),
		 .rce_a(rce_a),
		 .ra_a(ra_a),
		 .rq_a(rq_a),
		 .wce_a(wce_a),
		 .wa_a(wa_a),
		 .wd_a(wd_a),
		 .clk_b(clk_b),
		 .rce_b(rce_b),
		 .ra_b(ra_b),
		 .rq_b(rq_b),
		 .wce_b(wce_b),
		 .wa_b(wa_b),
		 .wd_b(wd_b));

endmodule

module BRAM_TDP_32x1024(
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

parameter AWIDTH = 10;
parameter DWIDTH = 32;

	input			clk_a;
	input                   rce_a;
	input      [AWIDTH-1:0] ra_a;
	output     [DWIDTH-1:0] rq_a;
	input                   wce_a;
	input      [AWIDTH-1:0] wa_a;
	input      [DWIDTH-1:0] wd_a;
	input			clk_b;
	input                   rce_b;
	input      [AWIDTH-1:0] ra_b;
	output     [DWIDTH-1:0] rq_b;
	input                   wce_b;
	input      [AWIDTH-1:0] wa_b;
	input      [DWIDTH-1:0] wd_b;

BRAM_TDP #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_TDP_32x1024 (.clk_a(clk_a),
		 .rce_a(rce_a),
		 .ra_a(ra_a),
		 .rq_a(rq_a),
		 .wce_a(wce_a),
		 .wa_a(wa_a),
		 .wd_a(wd_a),
		 .clk_b(clk_b),
		 .rce_b(rce_b),
		 .ra_b(ra_b),
		 .rq_b(rq_b),
		 .wce_b(wce_b),
		 .wa_b(wa_b),
		 .wd_b(wd_b));

endmodule

module BRAM_TDP_18x2048(
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

parameter AWIDTH = 11;
parameter DWIDTH = 18;

	input			clk_a;
	input                   rce_a;
	input      [AWIDTH-1:0] ra_a;
	output     [DWIDTH-1:0] rq_a;
	input                   wce_a;
	input      [AWIDTH-1:0] wa_a;
	input      [DWIDTH-1:0] wd_a;

	input			clk_b;
	input                   rce_b;
	input      [AWIDTH-1:0] ra_b;
	output     [DWIDTH-1:0] rq_b;
	input                   wce_b;
	input      [AWIDTH-1:0] wa_b;
	input      [DWIDTH-1:0] wd_b;

BRAM_TDP #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_TDP_18x2048 (.clk_a(clk_a),
		 .rce_a(rce_a),
		 .ra_a(ra_a),
		 .rq_a(rq_a),
		 .wce_a(wce_a),
		 .wa_a(wa_a),
		 .wd_a(wd_a),
		 .clk_b(clk_b),
		 .rce_b(rce_b),
		 .ra_b(ra_b),
		 .rq_b(rq_b),
		 .wce_b(wce_b),
		 .wa_b(wa_b),
		 .wd_b(wd_b));
endmodule

module BRAM_TDP_16x2048(
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

parameter AWIDTH = 11;
parameter DWIDTH = 16;

	input			clk_a;
	input                   rce_a;
	input      [AWIDTH-1:0] ra_a;
	output     [DWIDTH-1:0] rq_a;
	input                   wce_a;
	input      [AWIDTH-1:0] wa_a;
	input      [DWIDTH-1:0] wd_a;

	input			clk_b;
	input                   rce_b;
	input      [AWIDTH-1:0] ra_b;
	output     [DWIDTH-1:0] rq_b;
	input                   wce_b;
	input      [AWIDTH-1:0] wa_b;
	input      [DWIDTH-1:0] wd_b;

BRAM_TDP #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_TDP_16x2048 (.clk_a(clk_a),
		 .rce_a(rce_a),
		 .ra_a(ra_a),
		 .rq_a(rq_a),
		 .wce_a(wce_a),
		 .wa_a(wa_a),
		 .wd_a(wd_a),
		 .clk_b(clk_b),
		 .rce_b(rce_b),
		 .ra_b(ra_b),
		 .rq_b(rq_b),
		 .wce_b(wce_b),
		 .wa_b(wa_b),
		 .wd_b(wd_b));
endmodule

module BRAM_TDP_9x4096(
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

parameter AWIDTH = 12;
parameter DWIDTH = 9;

	input			clk_a;
	input                   rce_a;
	input      [AWIDTH-1:0] ra_a;
	output     [DWIDTH-1:0] rq_a;
	input                   wce_a;
	input      [AWIDTH-1:0] wa_a;
	input      [DWIDTH-1:0] wd_a;

	input			clk_b;
	input                   rce_b;
	input      [AWIDTH-1:0] ra_b;
	output     [DWIDTH-1:0] rq_b;
	input                   wce_b;
	input      [AWIDTH-1:0] wa_b;
	input      [DWIDTH-1:0] wd_b;

BRAM_TDP #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_TDP_9x4096 (.clk_a(clk_a),
		 .rce_a(rce_a),
		 .ra_a(ra_a),
		 .rq_a(rq_a),
		 .wce_a(wce_a),
		 .wa_a(wa_a),
		 .wd_a(wd_a),
		 .clk_b(clk_b),
		 .rce_b(rce_b),
		 .ra_b(ra_b),
		 .rq_b(rq_b),
		 .wce_b(wce_b),
		 .wa_b(wa_b),
		 .wd_b(wd_b));
endmodule

module BRAM_TDP_8x4096(
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

parameter AWIDTH = 12;
parameter DWIDTH = 8;

	input			clk_a;
	input                   rce_a;
	input      [AWIDTH-1:0] ra_a;
	output     [DWIDTH-1:0] rq_a;
	input                   wce_a;
	input      [AWIDTH-1:0] wa_a;
	input      [DWIDTH-1:0] wd_a;

	input			clk_b;
	input                   rce_b;
	input      [AWIDTH-1:0] ra_b;
	output     [DWIDTH-1:0] rq_b;
	input                   wce_b;
	input      [AWIDTH-1:0] wa_b;
	input      [DWIDTH-1:0] wd_b;

BRAM_TDP #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_TDP_8x4096 (.clk_a(clk_a),
		 .rce_a(rce_a),
		 .ra_a(ra_a),
		 .rq_a(rq_a),
		 .wce_a(wce_a),
		 .wa_a(wa_a),
		 .wd_a(wd_a),
		 .clk_b(clk_b),
		 .rce_b(rce_b),
		 .ra_b(ra_b),
		 .rq_b(rq_b),
		 .wce_b(wce_b),
		 .wa_b(wa_b),
		 .wd_b(wd_b));
endmodule

module BRAM_TDP_4x8192(
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

parameter AWIDTH = 13;
parameter DWIDTH = 4;

	input			clk_a;
	input                   rce_a;
	input      [AWIDTH-1:0] ra_a;
	output     [DWIDTH-1:0] rq_a;
	input                   wce_a;
	input      [AWIDTH-1:0] wa_a;
	input      [DWIDTH-1:0] wd_a;

	input			clk_b;
	input                   rce_b;
	input      [AWIDTH-1:0] ra_b;
	output     [DWIDTH-1:0] rq_b;
	input                   wce_b;
	input      [AWIDTH-1:0] wa_b;
	input      [DWIDTH-1:0] wd_b;

BRAM_TDP #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_TDP_4x8192 (.clk_a(clk_a),
		 .rce_a(rce_a),
		 .ra_a(ra_a),
		 .rq_a(rq_a),
		 .wce_a(wce_a),
		 .wa_a(wa_a),
		 .wd_a(wd_a),
		 .clk_b(clk_b),
		 .rce_b(rce_b),
		 .ra_b(ra_b),
		 .rq_b(rq_b),
		 .wce_b(wce_b),
		 .wa_b(wa_b),
		 .wd_b(wd_b));
endmodule

module BRAM_TDP_2x16384(
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

parameter AWIDTH = 14;
parameter DWIDTH = 2;

	input			clk_a;
	input                   rce_a;
	input      [AWIDTH-1:0] ra_a;
	output     [DWIDTH-1:0] rq_a;
	input                   wce_a;
	input      [AWIDTH-1:0] wa_a;
	input      [DWIDTH-1:0] wd_a;

	input			clk_b;
	input                   rce_b;
	input      [AWIDTH-1:0] ra_b;
	output     [DWIDTH-1:0] rq_b;
	input                   wce_b;
	input      [AWIDTH-1:0] wa_b;
	input      [DWIDTH-1:0] wd_b;

BRAM_TDP #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_TDP_2x16384 (.clk_a(clk_a),
		 .rce_a(rce_a),
		 .ra_a(ra_a),
		 .rq_a(rq_a),
		 .wce_a(wce_a),
		 .wa_a(wa_a),
		 .wd_a(wd_a),
		 .clk_b(clk_b),
		 .rce_b(rce_b),
		 .ra_b(ra_b),
		 .rq_b(rq_b),
		 .wce_b(wce_b),
		 .wa_b(wa_b),
		 .wd_b(wd_b));
endmodule

module BRAM_TDP_1x32768(
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

parameter AWIDTH = 15;
parameter DWIDTH = 1;

	input			clk_a;
	input                   rce_a;
	input      [AWIDTH-1:0] ra_a;
	output     [DWIDTH-1:0] rq_a;
	input                   wce_a;
	input      [AWIDTH-1:0] wa_a;
	input      [DWIDTH-1:0] wd_a;

	input			clk_b;
	input                   rce_b;
	input      [AWIDTH-1:0] ra_b;
	output     [DWIDTH-1:0] rq_b;
	input                   wce_b;
	input      [AWIDTH-1:0] wa_b;
	input      [DWIDTH-1:0] wd_b;

BRAM_TDP #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_TDP_2x32768 (.clk_a(clk_a),
		 .rce_a(rce_a),
		 .ra_a(ra_a),
		 .rq_a(rq_a),
		 .wce_a(wce_a),
		 .wa_a(wa_a),
		 .wd_a(wd_a),
		 .clk_b(clk_b),
		 .rce_b(rce_b),
		 .ra_b(ra_b),
		 .rq_b(rq_b),
		 .wce_b(wce_b),
		 .wa_b(wa_b),
		 .wd_b(wd_b));
endmodule
