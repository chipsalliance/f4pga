module top
(
    input  wire       clk,
    output wire [3:0] led,
    inout  wire       io
);

    reg [3:0] r;
    initial r <= 0;

    always @(posedge clk)
        r <= r + io;

    assign led = {r[0], r[1], r[2], r[3]};
    assign io  = r[0] ? 1 : 1'bz;

endmodule
