`default_nettype none
`timescale 1ns/1ps

module enhanced_gpu_tb;

    reg clk;
    reg reset;
    reg start;
    wire done;
    
    // Performance monitoring
    wire [31:0] total_cycles;
    wire [31:0] active_cycles;
    wire [7:0] pipeline_utilization;
    wire [15:0] instructions_completed;
    
    // Debug outputs
    wire [7:0] debug_core0_reg0;
    wire [7:0] debug_core1_reg0;
    wire [7:0] debug_memory_0;
    wire [7:0] debug_memory_16;
    
    // Instantiate enhanced GPU
    gpu_top #(
        .NUM_CORES(2),
        .THREADS_PER_CORE(2),
        .MEM_SIZE(32),
        .DATA_WIDTH(8),
        .ADDR_WIDTH(5)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .done(done),
        .total_cycles(total_cycles),
        .active_cycles(active_cycles),
        .pipeline_utilization(pipeline_utilization),
        .instructions_completed(instructions_completed),
        .debug_core0_reg0(debug_core0_reg0),
        .debug_core1_reg0(debug_core1_reg0),
        .debug_memory_0(debug_memory_0),
        .debug_memory_16(debug_memory_16)
    );
    
    // Clock generation - 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test sequence
    initial begin
        $dumpfile("enhanced_gpu_sim.vcd");
        $dumpvars(0, enhanced_gpu_tb);
        
        $display("=== Enhanced SIMD GPU Test ===");
        $display("4 threads processing array elements in parallel");
        $display("Input: [1,2,3,4] + [5,6,7,8] = Expected: [6,8,10,12]");
        
        // Reset
        reset = 1;
        start = 0;
        #20;
        reset = 0;
        #10;
        
        // Display initial memory state
        $display("\nInitial Memory State:");
        $display("Input array [0:3]: %d, %d, %d, %d", 
                dut.memory_inst.memory[0], dut.memory_inst.memory[1], 
                dut.memory_inst.memory[2], dut.memory_inst.memory[3]);
        $display("Input array [4:7]: %d, %d, %d, %d",
                dut.memory_inst.memory[4], dut.memory_inst.memory[5],
                dut.memory_inst.memory[6], dut.memory_inst.memory[7]);
        
        // Start SIMD execution
        $display("\nStarting SIMD execution...");
        start = 1;
        #10;
        start = 0;
        
        // Monitor execution
        fork
            // Monitor pipeline activity
            begin
                while (!done) begin
                    @(posedge clk);
                    if (dut.cores[0].threads[0].core_inst.active || 
                        dut.cores[0].threads[1].core_inst.active ||
                        dut.cores[1].threads[0].core_inst.active ||
                        dut.cores[1].threads[1].core_inst.active) begin
                        $display("Time %0t: Threads active, Pipeline util: %0d%%", 
                                $time, pipeline_utilization);
                    end
                end
            end
            
            // Wait for completion
            begin
                wait(done);
            end
        join_any
        
        #20;
        
        $display("\n=== SIMD Execution Complete ===");
        
        // Check results
        logic [7:0] result0, result1, result2, result3;
        result0 = dut.memory_inst.memory[16];
        result1 = dut.memory_inst.memory[17];
        result2 = dut.memory_inst.memory[18];
        result3 = dut.memory_inst.memory[19];
        
        $display("Results:");
        $display("  Thread 0 (1+5): %d (expected: 6)", result0);
        $display("  Thread 1 (2+6): %d (expected: 8)", result1);
        $display("  Thread 2 (3+7): %d (expected: 10)", result2);
        $display("  Thread 3 (4+8): %d (expected: 12)", result3);
        
        // Performance Analysis
        $display("\n=== Performance Analysis ===");
        $display("Total cycles: %0d", total_cycles);
        $display("Active cycles: %0d", active_cycles);
        $display("Instructions completed: %0d", instructions_completed);
        $display("Pipeline utilization: %0d%%", pipeline_utilization);
        
        // Calculate speedup vs single-threaded baseline
        // Single-threaded would take: 4 elements * 5 instructions/element = 20 cycles minimum
        // Plus pipeline overhead = ~25 cycles
        real theoretical_single_thread_cycles = 25.0;
        real actual_speedup = theoretical_single_thread_cycles / active_cycles;
        
        $display("Estimated speedup vs single-thread: %.2fx", actual_speedup);
        
        // Verify correctness
        logic test_passed = 1;
        if (result0 != 6) begin
            $display("FAIL: Thread 0 result incorrect");
            test_passed = 0;
        end
        if (result1 != 8) begin
            $display("FAIL: Thread 1 result incorrect");
            test_passed = 0;
        end
        if (result2 != 10) begin
            $display("FAIL: Thread 2 result incorrect");
            test_passed = 0;
        end
        if (result3 != 12) begin
            $display("FAIL: Thread 3 result incorrect");
            test_passed = 0;
        end
        
        if (test_passed) begin
            $display("\n✓ TEST PASSED: All 4 threads computed correctly in parallel");
            
            // Check if we achieved reasonable speedup and utilization
            if (actual_speedup >= 1.8) begin
                $display("✓ PERFORMANCE PASSED: Achieved %.2fx speedup (target: >1.8x)", actual_speedup);
            end else begin
                $display("⚠ PERFORMANCE WARNING: Speedup %.2fx below target 1.8x", actual_speedup);
            end
            
            if (pipeline_utilization >= 70) begin
                $display("✓ PIPELINE PASSED: %0d%% utilization (target: >70%%)", pipeline_utilization);
            end else begin
                $display("⚠ PIPELINE WARNING: %0d%% utilization below target 70%%", pipeline_utilization);
            end
        end else begin
            $display("\n✗ TEST FAILED: Incorrect SIMD computation results");
        end
        
        // Display thread-specific information
        $display("\n=== Thread Details ===");
        for (int i = 0; i < 4; i++) begin
            $display("Thread %0d: threadIdx=%0d, blockIdx=%0d", 
                    i, i, i/2);
        end
        
        #50;
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #50000;  // 50us timeout
        $display("ERROR: Test timeout - possible deadlock");
        $finish;
    end
    
    // Pipeline stage monitoring for detailed analysis
    always @(posedge clk) begin
        if (!reset && done) begin
            // Final detailed analysis
            $display("\nDetailed Pipeline Analysis:");
            $display("  Stall cycles: %0d", dut.perf_monitor.stall_cycles);
            $display("  Pipeline bubbles: %0d", dut.perf_monitor.pipeline_bubbles);
            $display("  Efficiency: %.1f%%", 
                    (real'(instructions_completed) / (real'(total_cycles) * 3)) * 100);
        end
    end

endmodule

`default_nettype wire
