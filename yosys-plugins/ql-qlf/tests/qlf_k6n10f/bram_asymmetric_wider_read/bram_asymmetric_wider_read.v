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

module spram_16x2048_32x1024 (
	clk,
	rce,
	ra,
	rq,
	wce,
	wa,
	wd
);
	input clk;
	input rce;
	input [9:0] ra;
	output reg [31:0] rq;
	input wce;
	input [10:0] wa;
	input [15:0] wd;
	reg [31:0] memory [0:1023];
	always @(posedge clk) begin
		if (rce)
			rq <= memory[ra];
		if (wce)
			memory[wa / 2][(wa % 2) * 16+:16] <= wd;
	end
	integer i;
	initial for (i = 0; i < 1024; i = i + 1)
		memory[i] = 0;
endmodule

module spram_8x2048_16x1024 (
	clk,
	rce,
	ra,
	rq,
	wce,
	wa,
	wd
);
	input clk;
	input rce;
	input [9:0] ra;
	output reg [15:0] rq;
	input wce;
	input [10:0] wa;
	input [7:0] wd;
	reg [15:0] memory [0:1023];
	always @(posedge clk) begin
		if (rce)
			rq <= memory[ra];
		if (wce)
			memory[wa / 2][(wa % 2) * 8+:8] <= wd;
	end
	integer i;
	initial for (i = 0; i < 1024; i = i + 1)
		memory[i] = 0;
endmodule

module spram_8x4096_16x2048 (
	clk,
	rce,
	ra,
	rq,
	wce,
	wa,
	wd
);
	input clk;
	input rce;
	input [10:0] ra;
	output reg [15:0] rq;
	input wce;
	input [11:0] wa;
	input [7:0] wd;
	reg [15:0] memory [0:2047];
	always @(posedge clk) begin
		if (rce)
			rq <= memory[ra];
		if (wce)
			memory[wa / 2][(wa % 2) * 8+:8] <= wd;
	end
	integer i;
	initial for (i = 0; i < 2048; i = i + 1)
		memory[i] = 0;
endmodule

module spram_8x4096_32x1024 (
	clk,
	rce,
	ra,
	rq,
	wce,
	wa,
	wd
);
	input clk;
	input rce;
	input [9:0] ra;
	output reg [31:0] rq;
	input wce;
	input [11:0] wa;
	input [7:0] wd;
	reg [31:0] memory [0:1023];
	always @(posedge clk) begin
		if (rce)
			rq <= memory[ra];
		if (wce)
			memory[wa / 4][(wa % 4) * 8+:8] <= wd;
	end
	integer i;
	initial for (i = 0; i < 1024; i = i + 1)
		memory[i] = 0;
endmodule
