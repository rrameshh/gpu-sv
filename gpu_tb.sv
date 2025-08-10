`default_nettype none
`timescale 1ns/1ps

module gpu_tb;

    reg clk;
    reg reset;
    reg start;
    wire done;
    
    wire [7:0] debug_core0_reg0;
    wire [7:0] debug_core1_reg0;
    wire [7:0] debug_memory_0;
    wire [7:0] debug_memory_8;
    
    // Instantiate GPU
    gpu_top #(
        .NUM_CORES(2),
        .THREADS_PER_CORE(1),
        .MEM_SIZE(16),
        .DATA_WIDTH(8),
        .ADDR_WIDTH(4)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .done(done),
        .debug_core0_reg0(debug_core0_reg0),
        .debug_core1_reg0(debug_core1_reg0),
        .debug_memory_0(debug_memory_0),
        .debug_memory_8(debug_memory_8)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz
    end
    
    // Test sequence
    initial begin
        $dumpfile("gpu_sim.vcd");
        $dumpvars(0, gpu_tb);
        
        // Reset
        reset = 1;
        start = 0;
        #20;
        reset = 0;
        #10;
        
        $display("Initial memory[0] = %d, memory[8] = %d", debug_memory_0, debug_memory_8);
        
        // Start execution
        start = 1;
        #10;
        start = 0;
        
        // Wait for completion
        wait(done);
        #20;
        
        $display("=== Execution Complete ===");
        $display("Final memory[0] = %d, memory[8] = %d", debug_memory_0, debug_memory_8);
        $display("Expected: memory[8] = 8 (5+3), memory[9] = 9 (7+2)");
        
        // Check results
        if (dut.memory_inst.memory[8] == 8 && dut.memory_inst.memory[9] == 9) begin
            $display("TEST PASSED: Both cores computed correctly");
        end else begin
            $display("TEST FAILED: Results incorrect");
            $display("  Got: memory[8]=%d, memory[9]=%d", 
                     dut.memory_inst.memory[8], dut.memory_inst.memory[9]);
        end
        
        #50;
        $finish;
    end
    
    // Timeout
    initial begin
        #10000;
        $display("TEST TIMEOUT");
        $finish;
    end

endmodule
