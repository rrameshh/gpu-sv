`default_nettype none

module alu #(
    parameter DATA_WIDTH = 8
) (
    input wire [DATA_WIDTH-1:0] a,
    input wire [DATA_WIDTH-1:0] b,
    output reg [DATA_WIDTH-1:0] result
);

    always_comb begin
        result = a + b;  // Only ADD for now
    end

endmodule
