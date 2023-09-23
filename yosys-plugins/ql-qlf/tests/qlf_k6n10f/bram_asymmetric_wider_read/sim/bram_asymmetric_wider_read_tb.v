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

`timescale 1ns/1ps

`define STRINGIFY(x) `"x`"

module TB;
	localparam PERIOD = 50;
	localparam ADDR_INCR = 1;

	reg clk;
	reg rce;
	reg [`READ_ADDR_WIDTH-1:0] ra;
	wire [`READ_DATA_WIDTH-1:0] rq;
	reg wce;
	reg [`WRITE_ADDR_WIDTH-1:0] wa;
	reg [`WRITE_DATA_WIDTH-1:0] wd;

	initial clk = 0;
	initial ra = 0;
	initial rce = 0;
	initial forever #(PERIOD / 2.0) clk = ~clk;
	initial begin
		$dumpfile(`STRINGIFY(`VCD));
		$dumpvars;
	end

	integer a;

	reg done;
	initial done = 1'b0;

	reg [`READ_DATA_WIDTH-1:0] expected;

	always @(posedge clk) begin
		case (`READ_DATA_WIDTH / `WRITE_DATA_WIDTH)
			1: expected <= (a | (a << 20) | 20'h55000) & {`WRITE_DATA_WIDTH{1'b1}};
			2: expected <= ((((2*a+1) | ((2*a+1) << 20) | 20'h55000) & {`WRITE_DATA_WIDTH{1'b1}}) << `WRITE_DATA_WIDTH) |
					(((2*a) | ((2*a) << 20) | 20'h55000) & {`WRITE_DATA_WIDTH{1'b1}});
			4: expected <= (((4*a) | ((4*a) << 20) | 20'h55000) & {`WRITE_DATA_WIDTH{1'b1}}) |
				      ((((4*a+1) | ((4*a+1) << 20) | 20'h55000) & {`WRITE_DATA_WIDTH{1'b1}}) << `WRITE_DATA_WIDTH) |
				      ((((4*a+2) | ((4*a+2) << 20) | 20'h55000) & {`WRITE_DATA_WIDTH{1'b1}}) << (2 * `WRITE_DATA_WIDTH)) |
				      ((((4*a+3) | ((4*a+3) << 20) | 20'h55000) & {`WRITE_DATA_WIDTH{1'b1}}) << (3 * `WRITE_DATA_WIDTH));
			default: expected <= ((a) | ((a) << 20) | 20'h55000) & {`WRITE_DATA_WIDTH{1'b1}};
		endcase
	end

	wire error = ((a != 0) && read_test) ? rq !== expected : 0;

	integer error_cnt = 0;
	always @ (posedge clk)
	begin
		if (error)
			error_cnt <= error_cnt + 1'b1;
	end

	reg read_test;
	initial read_test = 0;

	initial #(1) begin
		// Write data
		for (a = 0; a < (1<<`WRITE_ADDR_WIDTH); a = a + ADDR_INCR) begin
			@(negedge clk) begin
				wa = a;
				wd = a | (a << 20) | 20'h55000;
				wce = 1;
			end
			@(posedge clk) begin
				#(PERIOD/10) wce = 0;
			end
		end
		// Read data
		read_test = 1;
		for (a = 0; a < (1<<`READ_ADDR_WIDTH); a = a + ADDR_INCR) begin
			@(negedge clk) begin
				ra = a;
				rce = 1;
			end
			@(posedge clk) begin
				#(PERIOD/10) rce = 0;
				if ( rq !== expected) begin
					$display("%d: FAIL: mismatch act=%x exp=%x at %x", $time, rq, expected, a);
				end else begin
					$display("%d: OK: act=%x exp=%x at %x", $time, rq, expected, a);
				end
			end
		end
		done = 1'b1;
	end

	// Scan for simulation finish
	always @(posedge clk) begin
		if (done)
			$finish_and_return( (error_cnt == 0) ? 0 : -1 );
	end

	case (`STRINGIFY(`TOP))
		"spram_16x2048_32x1024": begin
			spram_16x2048_32x1024 #() simple (
				.clk(clk),
				.rce(rce),
				.ra(ra),
				.rq(rq),
				.wce(wce),
				.wa(wa),
				.wd(wd)
			);
		end
		"spram_8x4096_16x2048": begin
			spram_8x4096_16x2048 #() simple (
				.clk(clk),
				.rce(rce),
				.ra(ra),
				.rq(rq),
				.wce(wce),
				.wa(wa),
				.wd(wd)
			);
		end
		"spram_8x2048_16x1024": begin
			spram_8x2048_16x1024 #() simple (
				.clk(clk),
				.rce(rce),
				.ra(ra),
				.rq(rq),
				.wce(wce),
				.wa(wa),
				.wd(wd)
			);
		end
		"spram_8x4096_32x1024": begin
			spram_8x4096_32x1024 #() simple (
				.clk(clk),
				.rce(rce),
				.ra(ra),
				.rq(rq),
				.wce(wce),
				.wa(wa),
				.wd(wd)
			);
		end
	endcase
endmodule
