`default_nettype none

module performance_monitor #(
    parameter NUM_THREADS = 4,
    parameter PIPELINE_STAGES = 3
) (
    input wire clk,
    input wire reset,
    input wire start,
    
    // Per-thread monitoring
    input wire [NUM_THREADS-1:0] thread_active,
    input wire [NUM_THREADS-1:0] pipeline_stall,
    input wire [NUM_THREADS-1:0] instruction_valid,
    
    // Performance metrics
    output reg [31:0] total_cycles,
    output reg [31:0] active_cycles,
    output reg [7:0] pipeline_utilization,
    output reg [15:0] instructions_completed,
    
    // Detailed analysis
    output reg [31:0] pipeline_bubbles,
    output reg [31:0] stall_cycles,
    output reg [7:0] thread_utilization [NUM_THREADS-1:0]
);

    // Internal counters
    reg [31:0] cycle_counter;
    reg [31:0] instruction_counter;
    reg [31:0] stall_counter;
    reg [31:0] bubble_counter;
    reg [31:0] active_cycle_counter;
    
    // Per-thread counters
    reg [15:0] thread_instruction_count [NUM_THREADS-1:0];
    reg [31:0] thread_active_cycles [NUM_THREADS-1:0];
    
    // Pipeline efficiency tracking
    reg [2:0] active_stages;
    reg monitoring_active;
    
    always @(posedge clk) begin
        if (reset) begin
            // Reset all counters
            cycle_counter <= 32'h0;
            instruction_counter <= 32'h0;
            stall_counter <= 32'h0;
            bubble_counter <= 32'h0;
            active_cycle_counter <= 32'h0;
            monitoring_active <= 1'b0;
            
            // Reset per-thread counters
            for (int i = 0; i < NUM_THREADS; i++) begin
                thread_instruction_count[i] <= 16'h0;
                thread_active_cycles[i] <= 32'h0;
                thread_utilization[i] <= 8'h0;
            end
            
            // Reset outputs
            total_cycles <= 32'h0;
            active_cycles <= 32'h0;
            pipeline_utilization <= 8'h0;
            instructions_completed <= 16'h0;
            pipeline_bubbles <= 32'h0;
            stall_cycles <= 32'h0;
        end
        else begin
            // Start monitoring when execution begins
            if (start) begin
                monitoring_active <= 1'b1;
            end
            
            if (monitoring_active) begin
                // Increment cycle counter
                cycle_counter <= cycle_counter + 1'b1;
                
                // Count active cycles (when any thread is active)
                if (|thread_active) begin
                    active_cycle_counter <= active_cycle_counter + 1'b1;
                end
                
                // Count instructions completed
                for (int i = 0; i < NUM_THREADS; i++) begin
                    if (instruction_valid[i]) begin
                        instruction_counter <= instruction_counter + 1'b1;
                        thread_instruction_count[i] <= thread_instruction_count[i] + 1'b1;
                    end
                    
                    if (thread_active[i]) begin
                        thread_active_cycles[i] <= thread_active_cycles[i] + 1'b1;
                    end
                    
                    if (pipeline_stall[i]) begin
                        stall_counter <= stall_counter + 1'b1;
                    end
                end
                
                // Count pipeline stages active this cycle
                active_stages = 0;
                for (int i = 0; i < NUM_THREADS; i++) begin
                    if (thread_active[i]) active_stages = active_stages + 1'b1;
                end
                
                // Count pipeline bubbles (underutilized cycles)
                if (active_stages < PIPELINE_STAGES && |thread_active) begin
                    bubble_counter <= bubble_counter + (PIPELINE_STAGES - active_stages);
                end
                
                // Update outputs every 16 cycles for efficiency
                if (cycle_counter[3:0] == 4'hF) begin
                    total_cycles <= cycle_counter;
                    active_cycles <= active_cycle_counter;
                    instructions_completed <= instruction_counter[15:0];
                    pipeline_bubbles <= bubble_counter;
                    stall_cycles <= stall_counter;
                    
                    // Calculate pipeline utilization percentage
                    // Utilization = (Instructions completed) / (Cycles * Pipeline stages) * 100
                    if (cycle_counter > 0) begin
                        pipeline_utilization <= (instruction_counter * 100) / (cycle_counter * PIPELINE_STAGES);
                    end
                    
                    // Calculate per-thread utilization
                    for (int i = 0; i < NUM_THREADS; i++) begin
                        if (cycle_counter > 0) begin
                            thread_utilization[i] <= (thread_active_cycles[i] * 100) / cycle_counter;
                        end
                    end
                end
                
                // Stop monitoring when all threads are done
                if (!|thread_active && cycle_counter > 10) begin
                    monitoring_active <= 1'b0;
                end
            end
        end
    end
    
    // Real-time speedup calculation (compared to single-threaded baseline)
    reg [7:0] speedup_factor;
    always_comb begin
        // Theoretical speedup = Number of active threads
        // Actual speedup accounts for pipeline efficiency
        if (active_cycle_counter > 0 && instructions_completed > 0) begin
            // Simplified speedup metric: instructions per active cycle
            speedup_factor = (instructions_completed * 10) / active_cycle_counter[7:0];
        end else begin
            speedup_factor = 8'h0;
        end
    end

endmodule

`default_nettype wire
