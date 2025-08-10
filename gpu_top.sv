`default_nettype none
`timescale 1ns/1ps

module gpu_top #(
    parameter NUM_CORES = 2,
    parameter THREADS_PER_CORE = 1,  // Start with 1, expand to 2 in Week 2
    parameter MEM_SIZE = 16,
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
) (
    input wire clk,
    input wire reset,
    input wire start,
    output wire done,
    
    // Debug outputs
    output wire [DATA_WIDTH-1:0] debug_core0_reg0,
    output wire [DATA_WIDTH-1:0] debug_core1_reg0,
    output wire [DATA_WIDTH-1:0] debug_memory_0,
    output wire [DATA_WIDTH-1:0] debug_memory_8
);

    // Memory interface
    wire [NUM_CORES-1:0] mem_read_en;
    wire [NUM_CORES-1:0] mem_write_en;
    wire [ADDR_WIDTH-1:0] mem_addr [NUM_CORES-1:0];
    wire [DATA_WIDTH-1:0] mem_write_data [NUM_CORES-1:0];
    wire [DATA_WIDTH-1:0] mem_read_data [NUM_CORES-1:0];
    
    // Core status
    wire [NUM_CORES-1:0] core_done;
    assign done = &core_done;  // All cores done
    
    // Instantiate cores
    genvar i;
    generate
        for (i = 0; i < NUM_CORES; i++) begin : cores
            core #(
                .CORE_ID(i),
                .DATA_WIDTH(DATA_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH)
            ) core_inst (
                .clk(clk),
                .reset(reset),
                .start(start),
                .done(core_done[i]),
                
                .mem_read_en(mem_read_en[i]),
                .mem_write_en(mem_write_en[i]),
                .mem_addr(mem_addr[i]),
                .mem_write_data(mem_write_data[i]),
                .mem_read_data(mem_read_data[i]),
                
                .debug_reg0(i == 0 ? debug_core0_reg0 : debug_core1_reg0)
            );
        end
    endgenerate
    
    // Shared memory
    shared_memory #(
        .MEM_SIZE(MEM_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .NUM_PORTS(NUM_CORES)
    ) memory_inst (
        .clk(clk),
        .reset(reset),
        
        .read_en(mem_read_en),
        .write_en(mem_write_en),
        .addr(mem_addr),
        .write_data(mem_write_data),
        .read_data(mem_read_data),
        
        .debug_data_0(debug_memory_0),
        .debug_data_8(debug_memory_8)
    );

endmodule
