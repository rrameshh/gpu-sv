`default_nettype none

module gpu_register_file #(
    parameter THREAD_ID = 0,
    parameter BLOCK_ID = 0,
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

    // Register definitions (GPU-style special registers)
    localparam [1:0]
        REG_R0 = 2'b00,        // General purpose
        REG_R1 = 2'b01,        // General purpose  
        REG_THREAD_IDX = 2'b10, // %threadIdx - current thread ID
        REG_BLOCK_IDX = 2'b11;  // %blockIdx - current block ID + base address

    reg [DATA_WIDTH-1:0] registers [NUM_REGISTERS-1:0];
    
    assign debug_reg0 = registers[REG_R0];
    
    // Initialize special GPU registers
    initial begin
        registers[REG_R0] = 8'h0;                    // R0 = 0 (general purpose)
        registers[REG_R1] = 8'h0;                    // R1 = 0 (general purpose)
        registers[REG_THREAD_IDX] = THREAD_ID;       // R2 = threadIdx
        registers[REG_BLOCK_IDX] = THREAD_ID;        // R3 = base address for this thread
    end
    
    // Read ports - special handling for GPU registers
    always_comb begin
        case (read_addr1)
            REG_R0: read_data1 = registers[REG_R0];
            REG_R1: read_data1 = registers[REG_R1];
            REG_THREAD_IDX: read_data1 = THREAD_ID;        // Always return current threadIdx
            REG_BLOCK_IDX: read_data1 = registers[REG_BLOCK_IDX];
            default: read_data1 = 8'h0;
        endcase
        
        case (read_addr2)
            REG_R0: read_data2 = registers[REG_R0];
            REG_R1: read_data2 = registers[REG_R1];
            REG_THREAD_IDX: read_data2 = THREAD_ID;        // Always return current threadIdx
            REG_BLOCK_IDX: read_data2 = registers[REG_BLOCK_IDX];
            default: read_data2 = 8'h0;
        endcase
    end
    
    // Write port - protect special registers
    always @(posedge clk) begin
        if (reset) begin
            registers[REG_R0] <= 8'h0;
            registers[REG_R1] <= 8'h0;
            registers[REG_THREAD_IDX] <= THREAD_ID;
            registers[REG_BLOCK_IDX] <= THREAD_ID;
        end 
        else if (write_en) begin
            case (write_addr)
                REG_R0: registers[REG_R0] <= write_data;           // Writable
                REG_R1: registers[REG_R1] <= write_data;           // Writable
                REG_THREAD_IDX: begin
                    // threadIdx is read-only, ignore writes
                    // registers[REG_THREAD_IDX] <= THREAD_ID;
                end
                REG_BLOCK_IDX: registers[REG_BLOCK_IDX] <= write_data; // Can be used as base pointer
            endcase
        end
    end

endmodule

`default_nettype wire
