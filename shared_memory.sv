`default_nettype none

module shared_memory #(
    parameter MEM_SIZE = 16,
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4,
    parameter NUM_PORTS = 2
) (
    input wire clk,
    input wire reset,
    
    input wire [NUM_PORTS-1:0] read_en,
    input wire [NUM_PORTS-1:0] write_en,
    input wire [ADDR_WIDTH-1:0] addr [NUM_PORTS-1:0],
    input wire [DATA_WIDTH-1:0] write_data [NUM_PORTS-1:0],
    output reg [DATA_WIDTH-1:0] read_data [NUM_PORTS-1:0],
    
    // Debug outputs
    output wire [DATA_WIDTH-1:0] debug_data_0,
    output wire [DATA_WIDTH-1:0] debug_data_8
);

    reg [DATA_WIDTH-1:0] memory [MEM_SIZE-1:0];
    
    assign debug_data_0 = memory[0];
    assign debug_data_8 = memory[8];
    
    // Initialize with test data
    initial begin
        memory[0] = 8'd5;   // Test data
        memory[1] = 8'd3;
        memory[2] = 8'd7;
        memory[3] = 8'd2;
        // Rest initialized to 0
        for (int i = 4; i < MEM_SIZE; i++) begin
            memory[i] = 0;
        end
    end
    
    // Multi-port memory (simple arbitration - first port wins)
    always @(posedge clk) begin
        for (int i = 0; i < NUM_PORTS; i++) begin
            if (read_en[i]) begin
                read_data[i] <= memory[addr[i]];
            end
        end
        
        // Write arbitration - port 0 has priority
        for (int i = NUM_PORTS-1; i >= 0; i--) begin
            if (write_en[i]) begin
                memory[addr[i]] <= write_data[i];
            end
        end
    end

endmodule
