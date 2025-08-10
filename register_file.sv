`default_nettype none

module register_file #(
    parameter CORE_ID = 0,
    parameter DATA_WIDTH = 8,
    parameter NUM_REGISTERS = 4
) (
    input wire clk,
    input wire reset,
    
    input wire [1:0] read_addr1,
    input wire [1:0] read_addr2,
    output reg [DATA_WIDTH-1:0] read_data1,
    output reg [DATA_WIDTH-1:0] read_data2,
    
    input wire write_en,
    input wire [1:0] write_addr,
    input wire [DATA_WIDTH-1:0] write_data,
    
    output wire [DATA_WIDTH-1:0] debug_reg0
);

    reg [DATA_WIDTH-1:0] registers [NUM_REGISTERS-1:0];
    
    assign debug_reg0 = registers[0];
    
    // Initialize R3 with core-specific base address
    initial begin
        registers[0] = 0;
        registers[1] = 0; 
        registers[2] = 0;
        registers[3] = (CORE_ID == 0) ? 0 : 2;  // Base address for each core
    end
    
    // Read ports
    always_comb begin
        read_data1 = registers[read_addr1];
        read_data2 = registers[read_addr2];
    end
    
    // Write port
    always @(posedge clk) begin
        if (reset) begin
            registers[0] <= 0;
            registers[1] <= 0;
            registers[2] <= 0; 
            registers[3] <= (CORE_ID == 0) ? 0 : 2;
        end else if (write_en) begin
            registers[write_addr] <= write_data;
        end
    end

endmodule
