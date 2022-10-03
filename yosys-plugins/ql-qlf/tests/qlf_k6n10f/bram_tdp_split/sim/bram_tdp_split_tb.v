// Copyright (C) 2019-2022 The SymbiFlow Authors
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier: ISC

`timescale 1ns/1ps

`define STRINGIFY(x) `"x`"

module TB;
	localparam PERIOD = 50;
	localparam ADDR_INCR = 1;

	reg clk_a;
	reg rce_a;
	reg [`ADDR_WIDTH-1:0] ra_a;
	wire [`DATA_WIDTH-1:0] rq_a_0;
	wire [`DATA_WIDTH-1:0] rq_a_1;
	reg wce_a;
	reg [`ADDR_WIDTH-1:0] wa_a;
	reg [`DATA_WIDTH-1:0] wd_a_0;
	reg [`DATA_WIDTH-1:0] wd_a_1;

	reg clk_b;
	reg rce_b;
	reg [`ADDR_WIDTH-1:0] ra_b;
	wire [`DATA_WIDTH-1:0] rq_b_0;
	wire [`DATA_WIDTH-1:0] rq_b_1;
	reg wce_b;
	reg [`ADDR_WIDTH-1:0] wa_b;
	reg [`DATA_WIDTH-1:0] wd_b_0;
	reg [`DATA_WIDTH-1:0] wd_b_1;


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

	reg [`DATA_WIDTH-1:0] expected_a_0;
	reg [`DATA_WIDTH-1:0] expected_a_1;
	reg [`DATA_WIDTH-1:0] expected_b_0;
	reg [`DATA_WIDTH-1:0] expected_b_1;

	always @(posedge clk_a) begin
		expected_a_0 <= (a | (a << 20) | 20'h55000) & {`DATA_WIDTH{1'b1}};
		expected_a_1 <= ((a+1) | ((a+1) << 20) | 20'h55000) & {`DATA_WIDTH{1'b1}};
	end
	always @(posedge clk_b) begin
		expected_b_0 <= ((b+2) | ((b+2) << 20) | 20'h55000) & {`DATA_WIDTH{1'b1}};
		expected_b_1 <= ((b+3) | ((b+3) << 20) | 20'h55000) & {`DATA_WIDTH{1'b1}};
	end

	wire error_a_0 = a != 0 ? (rq_a_0 !== expected_a_0) : 0;
	wire error_a_1 = a != 0 ? (rq_a_1 !== expected_a_1) : 0;
	wire error_b_0 = b != (1<<`ADDR_WIDTH) / 2 ? (rq_b_0 !== expected_b_0) : 0;
	wire error_b_1 = b != (1<<`ADDR_WIDTH) / 2 ? (rq_b_1 !== expected_b_1) : 0;

	integer error_a_0_cnt = 0;
	integer error_a_1_cnt = 0;
	integer error_b_0_cnt = 0;
	integer error_b_1_cnt = 0;

	always @ (posedge clk_a)
	begin
		if (error_a_0)
			error_a_0_cnt <= error_a_0_cnt + 1'b1;
		if (error_a_1)
			error_a_1_cnt <= error_a_1_cnt + 1'b1;
	end
	always @ (posedge clk_b)
	begin
		if (error_b_0)
			error_b_0_cnt <= error_b_0_cnt + 1'b1;
		if (error_b_1)
			error_b_1_cnt <= error_b_1_cnt + 1'b1;
	end

	// PORTs A
	initial #(1) begin
		// Write data
		for (a = 0; a < (1<<`ADDR_WIDTH) / 2; a = a + ADDR_INCR) begin
			@(negedge clk_a) begin
				wa_a = a;
				wd_a_0 = a | (a << 20) | 20'h55000;
				wd_a_1 = (a+1) | ((a+1) << 20) | 20'h55000;
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
				if ( rq_a_0 !== expected_a_0) begin
					$display("%d: PORT A0: FAIL: mismatch act=%x exp=%x at %x", $time, rq_a_0, expected_a_0, a);
				end else begin
					$display("%d: PORT A0: OK: act=%x exp=%x at %x", $time, rq_a_0, expected_a_0, a);
				end
				if ( rq_a_1 !== expected_a_1) begin
					$display("%d: PORT A1: FAIL: mismatch act=%x exp=%x at %x", $time, rq_a_1, expected_a_1, a);
				end else begin
					$display("%d: PORT A1: OK: act=%x exp=%x at %x", $time, rq_a_1, expected_a_1, a);
				end
			end
		end
		done_a = 1'b1;
	end

	// PORTs B
	initial #(1) begin
		// Write data
		for (b = (1<<`ADDR_WIDTH) / 2; b < (1<<`ADDR_WIDTH); b = b + ADDR_INCR) begin
			@(negedge clk_b) begin
				wa_b = b;
				wd_b_0 = (b+2) | ((b+2) << 20) | 20'h55000;
				wd_b_1 = (b+3) | ((b+3) << 20) | 20'h55000;
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
				if ( rq_b_0 !== expected_b_0) begin
					$display("%d: PORT B0: FAIL: mismatch act=%x exp=%x at %x", $time, rq_b_0, expected_b_0, b);
				end else begin
					$display("%d: PORT B0: OK: act=%x exp=%x at %x", $time, rq_b_0, expected_b_0, b);
				end
				if ( rq_b_1 !== expected_b_1) begin
					$display("%d: PORT B1: FAIL: mismatch act=%x exp=%x at %x", $time, rq_b_1, expected_b_1, b);
				end else begin
					$display("%d: PORT B1: OK: act=%x exp=%x at %x", $time, rq_b_1, expected_b_1, b);
				end
			end
		end
		done_b = 1'b1;
	end

	// Scan for simulation finish
	always @(posedge clk_a, posedge clk_b) begin
		if (done_sim)
			$finish_and_return( (error_a_0_cnt == 0 & error_b_0_cnt == 0 & error_a_1_cnt == 0 & error_b_1_cnt == 0) ? 0 : -1 );
	end

	case (`STRINGIFY(`TOP))
		"BRAM_TDP_SPLIT_2x18x1024": begin
			BRAM_TDP_SPLIT_2x18x1024 #() bram (
				.clk_a_0(clk_a),
				.rce_a_0(rce_a),
				.ra_a_0(ra_a),
				.rq_a_0(rq_a_0),
				.wce_a_0(wce_a),
				.wa_a_0(wa_a),
				.wd_a_0(wd_a_0),
				.clk_b_0(clk_b),
				.rce_b_0(rce_b),
				.ra_b_0(ra_b),
				.rq_b_0(rq_b_0),
				.wce_b_0(wce_b),
				.wa_b_0(wa_b),
				.wd_b_0(wd_b_0),

				.clk_a_1(clk_a),
				.rce_a_1(rce_a),
				.ra_a_1(ra_a),
				.rq_a_1(rq_a_1),
				.wce_a_1(wce_a),
				.wa_a_1(wa_a),
				.wd_a_1(wd_a_1),
				.clk_b_1(clk_b),
				.rce_b_1(rce_b),
				.ra_b_1(ra_b),
				.rq_b_1(rq_b_1),
				.wce_b_1(wce_b),
				.wa_b_1(wa_b),
				.wd_b_1(wd_b_1)
			);
		end
		"BRAM_TDP_SPLIT_2x16x1024": begin
			BRAM_TDP_SPLIT_2x16x1024 #() bram (
				.clk_a_0(clk_a),
				.rce_a_0(rce_a),
				.ra_a_0(ra_a),
				.rq_a_0(rq_a_0),
				.wce_a_0(wce_a),
				.wa_a_0(wa_a),
				.wd_a_0(wd_a_0),
				.clk_b_0(clk_b),
				.rce_b_0(rce_b),
				.ra_b_0(ra_b),
				.rq_b_0(rq_b_0),
				.wce_b_0(wce_b),
				.wa_b_0(wa_b),
				.wd_b_0(wd_b_0),

				.clk_a_1(clk_a),
				.rce_a_1(rce_a),
				.ra_a_1(ra_a),
				.rq_a_1(rq_a_1),
				.wce_a_1(wce_a),
				.wa_a_1(wa_a),
				.wd_a_1(wd_a_1),
				.clk_b_1(clk_b),
				.rce_b_1(rce_b),
				.ra_b_1(ra_b),
				.rq_b_1(rq_b_1),
				.wce_b_1(wce_b),
				.wa_b_1(wa_b),
				.wd_b_1(wd_b_1)
			);
		end
		"BRAM_TDP_SPLIT_2x9x2048": begin
			BRAM_TDP_SPLIT_2x9x2048 #() bram (
				.clk_a_0(clk_a),
				.rce_a_0(rce_a),
				.ra_a_0(ra_a),
				.rq_a_0(rq_a_0),
				.wce_a_0(wce_a),
				.wa_a_0(wa_a),
				.wd_a_0(wd_a_0),
				.clk_b_0(clk_b),
				.rce_b_0(rce_b),
				.ra_b_0(ra_b),
				.rq_b_0(rq_b_0),
				.wce_b_0(wce_b),
				.wa_b_0(wa_b),
				.wd_b_0(wd_b_0),

				.clk_a_1(clk_a),
				.rce_a_1(rce_a),
				.ra_a_1(ra_a),
				.rq_a_1(rq_a_1),
				.wce_a_1(wce_a),
				.wa_a_1(wa_a),
				.wd_a_1(wd_a_1),
				.clk_b_1(clk_b),
				.rce_b_1(rce_b),
				.ra_b_1(ra_b),
				.rq_b_1(rq_b_1),
				.wce_b_1(wce_b),
				.wa_b_1(wa_b),
				.wd_b_1(wd_b_1)
			);
		end
		"BRAM_TDP_SPLIT_2x8x2048": begin
			BRAM_TDP_SPLIT_2x8x2048 #() bram (
				.clk_a_0(clk_a),
				.rce_a_0(rce_a),
				.ra_a_0(ra_a),
				.rq_a_0(rq_a_0),
				.wce_a_0(wce_a),
				.wa_a_0(wa_a),
				.wd_a_0(wd_a_0),
				.clk_b_0(clk_b),
				.rce_b_0(rce_b),
				.ra_b_0(ra_b),
				.rq_b_0(rq_b_0),
				.wce_b_0(wce_b),
				.wa_b_0(wa_b),
				.wd_b_0(wd_b_0),

				.clk_a_1(clk_a),
				.rce_a_1(rce_a),
				.ra_a_1(ra_a),
				.rq_a_1(rq_a_1),
				.wce_a_1(wce_a),
				.wa_a_1(wa_a),
				.wd_a_1(wd_a_1),
				.clk_b_1(clk_b),
				.rce_b_1(rce_b),
				.ra_b_1(ra_b),
				.rq_b_1(rq_b_1),
				.wce_b_1(wce_b),
				.wa_b_1(wa_b),
				.wd_b_1(wd_b_1)
			);
		end
		"BRAM_TDP_SPLIT_2x4x4096": begin
			BRAM_TDP_SPLIT_2x4x4096 #() bram (
				.clk_a_0(clk_a),
				.rce_a_0(rce_a),
				.ra_a_0(ra_a),
				.rq_a_0(rq_a_0),
				.wce_a_0(wce_a),
				.wa_a_0(wa_a),
				.wd_a_0(wd_a_0),
				.clk_b_0(clk_b),
				.rce_b_0(rce_b),
				.ra_b_0(ra_b),
				.rq_b_0(rq_b_0),
				.wce_b_0(wce_b),
				.wa_b_0(wa_b),
				.wd_b_0(wd_b_0),

				.clk_a_1(clk_a),
				.rce_a_1(rce_a),
				.ra_a_1(ra_a),
				.rq_a_1(rq_a_1),
				.wce_a_1(wce_a),
				.wa_a_1(wa_a),
				.wd_a_1(wd_a_1),
				.clk_b_1(clk_b),
				.rce_b_1(rce_b),
				.ra_b_1(ra_b),
				.rq_b_1(rq_b_1),
				.wce_b_1(wce_b),
				.wa_b_1(wa_b),
				.wd_b_1(wd_b_1)
			);
		end
		"BRAM_TDP_SPLIT_2x2x8192": begin
			BRAM_TDP_SPLIT_2x2x8192 #() bram (
				.clk_a_0(clk_a),
				.rce_a_0(rce_a),
				.ra_a_0(ra_a),
				.rq_a_0(rq_a_0),
				.wce_a_0(wce_a),
				.wa_a_0(wa_a),
				.wd_a_0(wd_a_0),
				.clk_b_0(clk_b),
				.rce_b_0(rce_b),
				.ra_b_0(ra_b),
				.rq_b_0(rq_b_0),
				.wce_b_0(wce_b),
				.wa_b_0(wa_b),
				.wd_b_0(wd_b_0),

				.clk_a_1(clk_a),
				.rce_a_1(rce_a),
				.ra_a_1(ra_a),
				.rq_a_1(rq_a_1),
				.wce_a_1(wce_a),
				.wa_a_1(wa_a),
				.wd_a_1(wd_a_1),
				.clk_b_1(clk_b),
				.rce_b_1(rce_b),
				.ra_b_1(ra_b),
				.rq_b_1(rq_b_1),
				.wce_b_1(wce_b),
				.wa_b_1(wa_b),
				.wd_b_1(wd_b_1)
			);
		end
		"BRAM_TDP_SPLIT_2x1x16384": begin
			BRAM_TDP_SPLIT_2x1x16384 #() bram (
				.clk_a_0(clk_a),
				.rce_a_0(rce_a),
				.ra_a_0(ra_a),
				.rq_a_0(rq_a_0),
				.wce_a_0(wce_a),
				.wa_a_0(wa_a),
				.wd_a_0(wd_a_0),
				.clk_b_0(clk_b),
				.rce_b_0(rce_b),
				.ra_b_0(ra_b),
				.rq_b_0(rq_b_0),
				.wce_b_0(wce_b),
				.wa_b_0(wa_b),
				.wd_b_0(wd_b_0),

				.clk_a_1(clk_a),
				.rce_a_1(rce_a),
				.ra_a_1(ra_a),
				.rq_a_1(rq_a_1),
				.wce_a_1(wce_a),
				.wa_a_1(wa_a),
				.wd_a_1(wd_a_1),
				.clk_b_1(clk_b),
				.rce_b_1(rce_b),
				.ra_b_1(ra_b),
				.rq_b_1(rq_b_1),
				.wce_b_1(wce_b),
				.wa_b_1(wa_b),
				.wd_b_1(wd_b_1)
			);
		end
	endcase
endmodule
