module top(input clk, input i, output o);

reg [0:0] outff = 0;

assign o = outff;

always @(posedge clk) begin
    outff <= i;
end

endmodule
