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

module BRAM_SDP #(parameter AWIDTH = 9,
parameter DWIDTH = 32)(
	clk,
	rce,
	ra,
	rq,
	wce,
	wa,
	wd
);

	input  			clk;

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

module BRAM_SDP_36x1024(
	clk,
	rce,
	ra,
	rq,
	wce,
	wa,
	wd
);

parameter AWIDTH = 10;
parameter DWIDTH = 36;

	input  			clk;
	input                   rce;
	input      [AWIDTH-1:0] ra;
	output     [DWIDTH-1:0] rq;
	input                   wce;
	input      [AWIDTH-1:0] wa;
	input      [DWIDTH-1:0] wd;

BRAM_SDP #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_36x1024 (.clk(clk),
		 .rce(rce),
		 .ra(ra),
		 .rq(rq),
		 .wce(wce),
		 .wa(wa),
		 .wd(wd));

endmodule

module BRAM_SDP_32x1024(
	clk,
	rce,
	ra,
	rq,
	wce,
	wa,
	wd
);

parameter AWIDTH = 10;
parameter DWIDTH = 32;

	input  			clk;
	input                   rce;
	input      [AWIDTH-1:0] ra;
	output     [DWIDTH-1:0] rq;
	input                   wce;
	input      [AWIDTH-1:0] wa;
	input      [DWIDTH-1:0] wd;

BRAM_SDP #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_32x1024 (.clk(clk),
		 .rce(rce),
		 .ra(ra),
		 .rq(rq),
		 .wce(wce),
		 .wa(wa),
		 .wd(wd));

endmodule

module BRAM_SDP_18x2048(
	clk,
	rce,
	ra,
	rq,
	wce,
	wa,
	wd
);

parameter AWIDTH = 11;
parameter DWIDTH = 18;

	input  			clk;
	input                   rce;
	input      [AWIDTH-1:0] ra;
	output     [DWIDTH-1:0] rq;
	input                   wce;
	input      [AWIDTH-1:0] wa;
	input      [DWIDTH-1:0] wd;

BRAM_SDP #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_18x2048 (.clk(clk),
		 .rce(rce),
		 .ra(ra),
		 .rq(rq),
		 .wce(wce),
		 .wa(wa),
		 .wd(wd));


endmodule

module BRAM_SDP_16x2048(
	clk,
	rce,
	ra,
	rq,
	wce,
	wa,
	wd
);

parameter AWIDTH = 11;
parameter DWIDTH = 16;

	input  			clk;
	input                   rce;
	input      [AWIDTH-1:0] ra;
	output     [DWIDTH-1:0] rq;
	input                   wce;
	input      [AWIDTH-1:0] wa;
	input      [DWIDTH-1:0] wd;

BRAM_SDP #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_16x2048 (.clk(clk),
		 .rce(rce),
		 .ra(ra),
		 .rq(rq),
		 .wce(wce),
		 .wa(wa),
		 .wd(wd));


endmodule

module BRAM_SDP_9x4096(
	clk,
	rce,
	ra,
	rq,
	wce,
	wa,
	wd
);

parameter AWIDTH = 12;
parameter DWIDTH = 9;

	input  			clk;
	input                   rce;
	input      [AWIDTH-1:0] ra;
	output     [DWIDTH-1:0] rq;
	input                   wce;
	input      [AWIDTH-1:0] wa;
	input      [DWIDTH-1:0] wd;

BRAM_SDP #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_9x4096 (.clk(clk),
		 .rce(rce),
		 .ra(ra),
		 .rq(rq),
		 .wce(wce),
		 .wa(wa),
		 .wd(wd));


endmodule

module BRAM_SDP_8x4096(
	clk,
	rce,
	ra,
	rq,
	wce,
	wa,
	wd
);

parameter AWIDTH = 12;
parameter DWIDTH = 8;

	input  			clk;
	input                   rce;
	input      [AWIDTH-1:0] ra;
	output     [DWIDTH-1:0] rq;
	input                   wce;
	input      [AWIDTH-1:0] wa;
	input      [DWIDTH-1:0] wd;

BRAM_SDP #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_8x4096 (.clk(clk),
		 .rce(rce),
		 .ra(ra),
		 .rq(rq),
		 .wce(wce),
		 .wa(wa),
		 .wd(wd));


endmodule

module BRAM_SDP_4x8192(
	clk,
	rce,
	ra,
	rq,
	wce,
	wa,
	wd
);

parameter AWIDTH = 13;
parameter DWIDTH = 4;

	input  			clk;
	input                   rce;
	input      [AWIDTH-1:0] ra;
	output     [DWIDTH-1:0] rq;
	input                   wce;
	input      [AWIDTH-1:0] wa;
	input      [DWIDTH-1:0] wd;

BRAM_SDP #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_4x8192 (.clk(clk),
		 .rce(rce),
		 .ra(ra),
		 .rq(rq),
		 .wce(wce),
		 .wa(wa),
		 .wd(wd));

endmodule

module BRAM_SDP_2x16384(
	clk,
	rce,
	ra,
	rq,
	wce,
	wa,
	wd
);

parameter AWIDTH = 14;
parameter DWIDTH = 2;

	input  			clk;
	input                   rce;
	input      [AWIDTH-1:0] ra;
	output     [DWIDTH-1:0] rq;
	input                   wce;
	input      [AWIDTH-1:0] wa;
	input      [DWIDTH-1:0] wd;

BRAM_SDP #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_2x16384 (.clk(clk),
		 .rce(rce),
		 .ra(ra),
		 .rq(rq),
		 .wce(wce),
		 .wa(wa),
		 .wd(wd));

endmodule

module BRAM_SDP_1x32768(
	clk,
	rce,
	ra,
	rq,
	wce,
	wa,
	wd
);

parameter AWIDTH = 15;
parameter DWIDTH = 1;

	input  			clk;
	input                   rce;
	input      [AWIDTH-1:0] ra;
	output     [DWIDTH-1:0] rq;
	input                   wce;
	input      [AWIDTH-1:0] wa;
	input      [DWIDTH-1:0] wd;

BRAM_SDP #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH))
	BRAM_1x32678 (.clk(clk),
		 .rce(rce),
		 .ra(ra),
		 .rq(rq),
		 .wce(wce),
		 .wa(wa),
		 .wd(wd));

endmodule
