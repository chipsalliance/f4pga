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


module \$__QLF_RAM16K (
	output [31:0] RDATA,
	input         RCLK, RE,
	input  [8:0] RADDR,
	input         WCLK, WE,
	input  [8:0] WADDR,
	input  [31:0] WENB,
	input  [31:0] WDATA
);

	generate
		DP_RAM16K #()
			_TECHMAP_REPLACE_ (
			.d_out(RDATA),
			.rclk (RCLK ),
			.wclk (WCLK ),
			.ren  (RE   ),
			.raddr(RADDR),
			.wen  (WE   ),
			.waddr(WADDR),
			.wenb (WENB ),
			.d_in (WDATA)
		);
	endgenerate

endmodule


module \$__QLF_RAM16K_M0 (CLK1, A1ADDR, A1DATA, A1EN, B1ADDR, B1DATA, B1EN);


	parameter [4095:0] INIT = 4096'bx;

	input CLK1;

	input [8:0] A1ADDR;
	output [31:0] A1DATA;
	input A1EN;

	input [8:0] B1ADDR;
	input [31:0] B1DATA;
	input B1EN;

	wire [31:0] WENB;
	assign WENB = 32'hFFFFFFFF;

	\$__QLF_RAM16K #()
		 _TECHMAP_REPLACE_ (
		.RDATA(A1DATA),
		.RADDR(A1ADDR),
		.RCLK (CLK1  ),
		.RE   (A1EN  ),
		.WDATA(B1DATA),
		.WADDR(B1ADDR),
		.WCLK (CLK1  ),
		.WE   (B1EN  ),
		.WENB (WENB  )
	);
endmodule


module \$__QLF_RAM16K_M1 (CLK1, A1ADDR, A1DATA, A1EN, B1ADDR, B1DATA, B1EN);


	parameter [4095:0] INIT = 4096'bx;

	input CLK1;

	input [9:0] A1ADDR;
	output [31:0] A1DATA;
	input A1EN;

	input [9:0] B1ADDR;
	input [31:0] B1DATA;
	input B1EN;

	wire [31:0] WENB;
	wire [31:0] WDATA;

	generate
		wire A1BAR;
		assign A1BAR = ~A1ADDR[0];
		assign WDATA = { {2{B1DATA[15:0]}}};
	endgenerate

	assign WENB = { {16{A1ADDR[0]}} , {16{A1BAR}}};


	\$__QLF_RAM16K #()
		 _TECHMAP_REPLACE_ (
		.RDATA(A1DATA     ),
		.RADDR(A1ADDR     ),
		.RCLK (CLK1       ),
		.RE   (A1EN       ),
		.WDATA(WDATA      ),
		.WADDR(B1ADDR[9:1]),
		.WCLK (CLK1       ),
		.WENB (WENB       ),
		.WE   (B1EN       )
	);

endmodule

module \$__QLF_RAM16K_M2 (CLK1, A1ADDR, A1DATA, A1EN, B1ADDR, B1DATA, B1EN);


	parameter [4095:0] INIT = 4096'bx;

	input CLK1;

	input [10:0] A1ADDR;
	output [31:0] A1DATA;
	input A1EN;

	input [10:0] B1ADDR;
	input [7:0] B1DATA;
	input B1EN;

	wire [31:0] WENB;
	wire [31:0] WDATA;

	generate
		wire A1BAR0, A1BAR1;
		assign A1BAR0 = ~A1ADDR[0];
		assign A1BAR1 = ~A1ADDR[1];
		assign WDATA = { {4{B1DATA[7:0]}}};
	endgenerate

	assign WENB = { {8{A1ADDR[1]& A1ADDR[0]}},
			{8{A1ADDR[1]& A1BAR0}}   , 
			{8{A1BAR1   & A1ADDR[0]}}, 
			{8{A1BAR1   & A1BAR0}}}	 ;


	\$__QLF_RAM16K #()
		 _TECHMAP_REPLACE_ (
		.RDATA(A1DATA      ),
		.RADDR(A1ADDR      ),
		.RCLK (CLK1        ),
		.RE   (A1EN        ),
		.WDATA(B1DATA      ),
		.WADDR(B1ADDR[10:2]),
		.WCLK (CLK1        ),
		.WENB (WENB        ),
		.WE   (B1EN        )
	);

endmodule

module \$__QLF_RAM16K_M3 (CLK1, A1ADDR, A1DATA, A1EN, B1ADDR, B1DATA, B1EN);

	parameter [4095:0] INIT = 4096'bx;

	input CLK1;

	input [11:0] A1ADDR;
	output [31:0] A1DATA;
	input A1EN;

	input [11:0] B1ADDR;
	input [3:0] B1DATA;
	input B1EN;

	wire [31:0] WENB;
	wire [31:0] WDATA;

	generate
		assign WDATA = { {8{B1DATA[3:0]}}};
		wire A1BAR0, A1BAR1, A1BAR2;
		assign A1BAR0 = ~A1ADDR[0];
		assign A1BAR1 = ~A1ADDR[1];
		assign A1BAR2 = ~A1ADDR[2];
	endgenerate

		assign WENB = { {4{A1ADDR[2] &A1ADDR[1] & A1ADDR[0]}}, 
				{4{A1ADDR[2] &A1ADDR[1] & A1BAR0}}   , 
				{4{A1ADDR[2] &A1BAR1    & A1ADDR[0]}}, 
				{4{A1ADDR[2] &A1BAR1    & A1BAR0}}   , 
				{4{A1BAR2    &A1ADDR[1] & A1ADDR[0]}}, 
				{4{A1BAR2    &A1ADDR[1] & A1BAR0}}   , 
				{4{A1BAR2    &A1BAR1    & A1ADDR[0]}}, 
				{4{A1BAR2    &A1BAR1    & A1BAR0}}}  ; 

	\$__QLF_RAM16K #()
		 _TECHMAP_REPLACE_ (
		.RDATA(A1DATA      ),
		.RADDR(A1ADDR      ),
		.RCLK (CLK1        ),
		.RE   (A1EN        ),
		.WDATA(B1DATA      ),
		.WADDR(B1ADDR[11:3]),
		.WCLK (CLK1        ),
		.WENB (WENB        ),
		.WE   (B1EN        )
	);

endmodule

