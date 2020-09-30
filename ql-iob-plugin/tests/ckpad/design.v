module top (
    input  wire clk0,
    input  wire clk1,
    (* clkbuf_inhibit *)
    input  wire clk2,
    (* clkbuf_inhibit *)
    input  wire clk3,

    input  wire [3:0] d,
    output reg  [3:0] q
);

    always @(posedge clk0)
        q[0] <= d[0];
    always @(posedge clk1)
        q[1] <= d[1];
    always @(posedge clk2)
        q[2] <= d[2];
    always @(posedge clk3)
        q[3] <= d[3];

endmodule
