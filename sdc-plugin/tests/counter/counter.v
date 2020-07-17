module top(input clk,
	input [1:0] in,
	output [1:0] out);

reg [1:0] cnt = 0;

always @(posedge clk) begin
	cnt <= cnt + 1;
end

assign out = {cnt[0], in[0]};
endmodule
/*
module dut();
reg clk;
wire [1:0] out;

top dut(.clk(clk), .in(2'b11), .out(out));
initial begin
	$dumpfile("test.vcd");
	$dumpvars(0,dut);
	clk = 0;
end

always
begin
	clk = #5 !clk;
end
endmodule
*/
