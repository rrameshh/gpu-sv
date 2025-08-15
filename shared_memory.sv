`default_nettype none

module shared_memory #(
    parameter MEM_SIZE = 32,
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 5,
    parameter NUM_PORTS = 4
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
    output wire [DATA_WIDTH-1:0] debug_data_16
);

    reg [DATA_WIDTH-1:0] memory [MEM_SIZE-1:0];
    
    assign debug_data_0 = memory[0];
    assign debug_data_16 = memory[16];
    
    // Initialize with SIMD test data
    // Array processing: input[0:7] + input[4:11] = output[16:19]
    initial begin
        // Input array [0:7]: 1,2,3,4,5,6,7,8
        memory[0] = 8'd1;   // Thread 0 reads this
        memory[1] = 8'd2;   // Thread 1 reads this
        memory[2] = 8'd3;   // Thread 2 reads this  
        memory[3] = 8'd4;   // Thread 3 reads this
        memory[4] = 8'd5;   // Thread 0 reads this
        memory[5] = 8'd6;   // Thread 1 reads this
        memory[6] = 8'd7;   // Thread 2 reads this
        memory[7] = 8'd8;   // Thread 3 reads this
        
        // Output array [16:19]: Results go here
        // Expected: [6,8,10,12] = [1+5, 2+6, 3+7, 4+8]
        memory[16] = 8'd0;  // Thread 0 writes result here
        memory[17] = 8'd0;  // Thread 1 writes result here
        memory[18] = 8'd0;  // Thread 2 writes result here
        memory[19] = 8'd0;  // Thread 3 writes result here
        
        // Initialize rest to 0
        for (int i = 8; i < 16; i++) begin
            memory[i] = 8'd0;
        end
        for (int i = 20; i < MEM_SIZE; i++) begin
            memory[i] = 8'd0;
        end
    end
    
    // Multi-port memory with banking and arbitration
    // Use simple round-robin arbitration for write conflicts
    reg [1:0] write_priority;
    
    always @(posedge clk) begin
        if (reset) begin
            write_priority <= 2'b00;
            // Reset read outputs
            for (int i = 0; i < NUM_PORTS; i++) begin
                read_data[i] <= 8'h0;
            end
        end else begin
            // Handle reads (no conflicts, all ports can read simultaneously)
            for (int i = 0; i < NUM_PORTS; i++) begin
                if (read_en[i]) begin
                    read_data[i] <= memory[addr[i]];
                end
            end
            
            // Handle writes with arbitration
            // Check for write conflicts (multiple ports writing to same address)
            reg [NUM_PORTS-1:0] conflict_mask;
            reg write_occurred;
            
            write_occurred = 1'b0;
            
            // Priority-based write arbitration
            for (int priority = 0; priority < NUM_PORTS; priority++) begin
                int port_idx = (write_priority + priority) % NUM_PORTS;
                
                if (write_en[port_idx] && !write_occurred) begin
                    // Check if any higher priority port is writing to same address
                    conflict_mask = '0;
                    for (int check_port = 0; check_port < NUM_PORTS; check_port++) begin
                        if (write_en[check_port] && (addr[check_port] == addr[port_idx]) && 
                            (check_port != port_idx)) begin
                            conflict_mask[check_port] = 1'b1;
                        end
                    end
                    
                    // If no conflicts or this port has priority, perform write
                    if (conflict_mask == '0 || priority == 0) begin
                        memory[addr[port_idx]] <= write_data[port_idx];
                        write_occurred = 1'b1;
                        
                        // Debug output for verification
                        if (addr[port_idx] >= 16 && addr[port_idx] <= 19) begin
                            $display("Thread %0d wrote %0d to result[%0d] at time %0t", 
                                    port_idx, write_data[port_idx], addr[port_idx]-16, $time);
                        end
                    end
                end
            end
            
            // Rotate write priority for fairness
            write_priority <= write_priority + 1'b1;
        end
    end
    
    // Memory access monitoring for performance analysis
    reg [31:0] read_access_count;
    reg [31:0] write_access_count;
    reg [31:0] conflict_count;
    
    always @(posedge clk) begin
        if (reset) begin
            read_access_count <= 32'h0;
            write_access_count <= 32'h0;
            conflict_count <= 32'h0;
        end else begin
            // Count memory accesses
            read_access_count <= read_access_count + $countones(read_en);
            write_access_count <= write_access_count + $countones(write_en);
            
            // Count write conflicts
            reg [NUM_PORTS-1:0] addr_conflict;
            addr_conflict = '0;
            
            for (int i = 0; i < NUM_PORTS; i++) begin
                for (int j = i+1; j < NUM_PORTS; j++) begin
                    if (write_en[i] && write_en[j] && (addr[i] == addr[j])) begin
                        addr_conflict[i] = 1'b1;
                        addr_conflict[j] = 1'b1;
                    end
                end
            end
            
            if (|addr_conflict) begin
                conflict_count <= conflict_count + 1'b1;
            end
        end
    end

endmodule

`default_nettype wire
