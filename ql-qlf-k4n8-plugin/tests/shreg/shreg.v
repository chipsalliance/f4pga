module top (
    input  wire I,
    input  wire C,
    output wire O
);

    reg [7:0] shift_register;

    always @(posedge C)
        shift_register <= {shift_register[6:0], I};

    assign O = shift_register[7];

endmodule
