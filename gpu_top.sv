`default_nettype none
`timescale 1ns/1ps

module gpu_top #(
    parameter NUM_CORES = 2,
    parameter THREADS_PER_CORE = 2,  // Now 2 threads per core = 4 total
    parameter TOTAL_THREADS = NUM_CORES * THREADS_PER_CORE,
    parameter MEM_SIZE = 32,         // Larger memory for more data
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 5,        // 5 bits for 32 locations
    parameter BLOCK_SIZE = 2         // 2 threads per block
) (
    input wire clk,
    input wire reset,
    input wire start,
    output wire done,
    
    // Performance outputs
    output wire [31:0] total_cycles,
    output wire [31:0] active_cycles,
    output wire [7:0] pipeline_utilization,
    output wire [15:0] instructions_completed,
    
    // Debug outputs
    output wire [DATA_WIDTH-1:0] debug_core0_reg0,
    output wire [DATA_WIDTH-1:0] debug_core1_reg0,
    output wire [DATA_WIDTH-1:0] debug_memory_0,
    output wire [DATA_WIDTH-1:0] debug_memory_16
);

    // Memory interface - now supports 4 threads
    wire [TOTAL_THREADS-1:0] mem_read_en;
    wire [TOTAL_THREADS-1:0] mem_write_en;
    wire [ADDR_WIDTH-1:0] mem_addr [TOTAL_THREADS-1:0];
    wire [DATA_WIDTH-1:0] mem_write_data [TOTAL_THREADS-1:0];
    wire [DATA_WIDTH-1:0] mem_read_data [TOTAL_THREADS-1:0];
    
    // Thread status
    wire [TOTAL_THREADS-1:0] thread_done;
    wire [TOTAL_THREADS-1:0] thread_active;
    assign done = &thread_done;  // All threads done
    
    // Performance monitoring signals
    wire [TOTAL_THREADS-1:0] pipeline_stall;
    wire [TOTAL_THREADS-1:0] instruction_valid;
    
    // Instantiate cores with multiple threads each
    genvar i, j;
    generate
        for (i = 0; i < NUM_CORES; i++) begin : cores
            for (j = 0; j < THREADS_PER_CORE; j++) begin : threads
                localparam THREAD_ID = i * THREADS_PER_CORE + j;
                localparam BLOCK_ID = THREAD_ID / BLOCK_SIZE;
                
                pipelined_core #(
                    .CORE_ID(i),
                    .THREAD_ID(THREAD_ID),
                    .BLOCK_ID(BLOCK_ID),
                    .DATA_WIDTH(DATA_WIDTH),
                    .ADDR_WIDTH(ADDR_WIDTH)
                ) core_inst (
                    .clk(clk),
                    .reset(reset),
                    .start(start),
                    .done(thread_done[THREAD_ID]),
                    .active(thread_active[THREAD_ID]),
                    
                    .mem_read_en(mem_read_en[THREAD_ID]),
                    .mem_write_en(mem_write_en[THREAD_ID]),
                    .mem_addr(mem_addr[THREAD_ID]),
                    .mem_write_data(mem_write_data[THREAD_ID]),
                    .mem_read_data(mem_read_data[THREAD_ID]),
                    
                    // Performance monitoring
                    .pipeline_stall(pipeline_stall[THREAD_ID]),
                    .instruction_valid(instruction_valid[THREAD_ID]),
                    
                    .debug_reg0((i == 0) ? debug_core0_reg0 : debug_core1_reg0)
                );
            end
        end
    endgenerate
    
    // Shared memory with multi-port access
    shared_memory #(
        .MEM_SIZE(MEM_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .NUM_PORTS(TOTAL_THREADS)
    ) memory_inst (
        .clk(clk),
        .reset(reset),
        
        .read_en(mem_read_en),
        .write_en(mem_write_en),
        .addr(mem_addr),
        .write_data(mem_write_data),
        .read_data(mem_read_data),
        
        .debug_data_0(debug_memory_0),
        .debug_data_16(debug_memory_16)
    );
    
    // Performance monitoring unit
    performance_monitor #(
        .NUM_THREADS(TOTAL_THREADS)
    ) perf_monitor (
        .clk(clk),
        .reset(reset),
        .start(start),
        .thread_active(thread_active),
        .pipeline_stall(pipeline_stall),
        .instruction_valid(instruction_valid),
        
        .total_cycles(total_cycles),
        .active_cycles(active_cycles),
        .pipeline_utilization(pipeline_utilization),
        .instructions_completed(instructions_completed)
    );

endmodule

`default_nettype wire
