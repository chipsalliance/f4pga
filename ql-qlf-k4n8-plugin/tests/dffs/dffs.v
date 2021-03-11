module my_dff ( input d, clk, output reg q );
    initial q <= 1'b0;
    always @( posedge clk )
        q <= d;
endmodule

