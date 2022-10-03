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

	reg clk_a;
	reg rce_a;
	reg [`ADDR_WIDTH-1:0] ra_a;
	wire [`DATA_WIDTH-1:0] rq_a;
	reg wce_a;
	reg [`ADDR_WIDTH-1:0] wa_a;
	reg [`DATA_WIDTH-1:0] wd_a;

	reg clk_b;
	reg rce_b;
	reg [`ADDR_WIDTH-1:0] ra_b;
	wire [`DATA_WIDTH-1:0] rq_b;
	reg wce_b;
	reg [`ADDR_WIDTH-1:0] wa_b;
	reg [`DATA_WIDTH-1:0] wd_b;


	initial clk_a = 0;
	initial clk_b = 0;
	initial ra_a = 0;
	initial ra_b = 0;
	initial rce_a = 0;
	initial rce_b = 0;
	initial forever #(PERIOD / 2.0) clk_a = ~clk_a;
	initial begin
		#(PERIOD / 4.0);
		forever #(PERIOD / 2.0) clk_b = ~clk_b;
	end
	initial begin
		$dumpfile(`STRINGIFY(`VCD));
		$dumpvars;
	end

	integer a;
	integer b;

	reg done_a;
	reg done_b;
	initial done_a = 1'b0;
	initial done_b = 1'b0;
	wire done_sim = done_a & done_b;

	reg [`DATA_WIDTH-1:0] expected_a;
	reg [`DATA_WIDTH-1:0] expected_b;

	always @(posedge clk_a) begin
		expected_a <= (a | (a << 20) | 20'h55000) & {`DATA_WIDTH{1'b1}};
	end
	always @(posedge clk_b) begin
		expected_b <= (b | (b << 20) | 20'h55000) & {`DATA_WIDTH{1'b1}};
	end

	wire error_a = a != 0 ? rq_a !== expected_a : 0;
	wire error_b = b != (1<<`ADDR_WIDTH) / 2 ? rq_b !== expected_b : 0;

	integer error_a_cnt = 0;
	integer error_b_cnt = 0;

	always @ (posedge clk_a)
	begin
		if (error_a)
			error_a_cnt <= error_a_cnt + 1'b1;
	end
	always @ (posedge clk_b)
	begin
		if (error_b)
			error_b_cnt <= error_b_cnt + 1'b1;
	end
	// PORT A
	initial #(1) begin
		// Write data
		for (a = 0; a < (1<<`ADDR_WIDTH) / 2; a = a + ADDR_INCR) begin
			@(negedge clk_a) begin
				wa_a = a;
				wd_a = a | (a << 20) | 20'h55000;
				wce_a = 1;
			end
			@(posedge clk_a) begin
				#(PERIOD/10) wce_a = 0;
			end
		end
		// Read data
		for (a = 0; a < (1<<`ADDR_WIDTH) / 2; a = a + ADDR_INCR) begin
			@(negedge clk_a) begin
				ra_a = a;
				rce_a = 1;
			end
			@(posedge clk_a) begin
				#(PERIOD/10) rce_a = 0;
				if ( rq_a !== expected_a) begin
					$display("%d: PORT A: FAIL: mismatch act=%x exp=%x at %x", $time, rq_a, expected_a, a);
				end else begin
					$display("%d: PORT A: OK: act=%x exp=%x at %x", $time, rq_a, expected_a, a);
				end
			end
		end
		done_a = 1'b1;
	end

	// PORT B
	initial #(1) begin
		// Write data
		for (b = (1<<`ADDR_WIDTH) / 2; b < (1<<`ADDR_WIDTH); b = b + ADDR_INCR) begin
			@(negedge clk_b) begin
				wa_b = b;
				wd_b = b | (b << 20) | 20'h55000;
				wce_b = 1;
			end
			@(posedge clk_b) begin
				#(PERIOD/10) wce_b = 0;
			end
		end
		// Read data
		for (b = (1<<`ADDR_WIDTH) / 2; b < (1<<`ADDR_WIDTH); b = b + ADDR_INCR) begin
			@(negedge clk_b) begin
				ra_b = b;
				rce_b = 1;
			end
			@(posedge clk_b) begin
				#(PERIOD/10) rce_b = 0;
				if ( rq_b !== expected_b) begin
					$display("%d: PORT B: FAIL: mismatch act=%x exp=%x at %x", $time, rq_b, expected_b, b);
				end else begin
					$display("%d: PORT B: OK: act=%x exp=%x at %x", $time, rq_b, expected_b, b);
				end
			end
		end
		done_b = 1'b1;
	end

	// Scan for simulation finish
	always @(posedge clk_a, posedge clk_b) begin
		if (done_sim)
			$finish_and_return( (error_a_cnt == 0 & error_b_cnt == 0) ? 0 : -1 );
	end

	case (`STRINGIFY(`TOP))
		"BRAM_TDP_36x1024": begin
			BRAM_TDP_36x1024 #() bram (
				.clk_a(clk_a),
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
				.wd_b(wd_b)
			);
		end
		"BRAM_TDP_32x1024": begin
			BRAM_TDP_32x1024 #() bram (
				.clk_a(clk_a),
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
				.wd_b(wd_b)
			);
		end
		"BRAM_TDP_18x2048": begin
			BRAM_TDP_18x2048 #() bram (
				.clk_a(clk_a),
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
				.wd_b(wd_b)
			);
		end
		"BRAM_TDP_16x2048": begin
			BRAM_TDP_16x2048 #() bram (
				.clk_a(clk_a),
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
				.wd_b(wd_b)
			);
		end
		"BRAM_TDP_9x4096": begin
			BRAM_TDP_9x4096 #() bram (
				.clk_a(clk_a),
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
				.wd_b(wd_b)
			);
		end
		"BRAM_TDP_8x4096": begin
			BRAM_TDP_8x4096 #() bram (
				.clk_a(clk_a),
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
				.wd_b(wd_b)
			);
		end
		"BRAM_TDP_4x8192": begin
			BRAM_TDP_4x8192 #() bram (
				.clk_a(clk_a),
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
				.wd_b(wd_b)
			);
		end
		"BRAM_TDP_2x16384": begin
			BRAM_TDP_2x16384 #() bram (
				.clk_a(clk_a),
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
				.wd_b(wd_b)
			);
		end
		"BRAM_TDP_1x32768": begin
			BRAM_TDP_1x32768 #() bram (
				.clk_a(clk_a),
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
				.wd_b(wd_b)
			);
		end
	endcase
endmodule
