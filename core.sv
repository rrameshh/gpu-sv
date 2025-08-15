`default_nettype none

module pipelined_core #(
    parameter CORE_ID = 0,
    parameter THREAD_ID = 0,
    parameter BLOCK_ID = 0,
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 5,
    parameter NUM_REGISTERS = 4
) (
    input wire clk,
    input wire reset,
    input wire start,
    output reg done,
    output reg active,
    
    // Memory interface
    output reg mem_read_en,
    output reg mem_write_en,
    output reg [ADDR_WIDTH-1:0] mem_addr,
    output reg [DATA_WIDTH-1:0] mem_write_data,
    input wire [DATA_WIDTH-1:0] mem_read_data,
    
    // Performance monitoring
    output reg pipeline_stall,
    output reg instruction_valid,
    
    // Debug output
    output wire [DATA_WIDTH-1:0] debug_reg0
);

    // Instruction encoding
    localparam [1:0] 
        OP_LOAD  = 2'b00,
        OP_ADD   = 2'b01,
        OP_STORE = 2'b10,
        OP_HALT  = 2'b11;
    
    // Pipeline stages
    typedef enum logic [1:0] {
        STAGE_FETCH = 2'b00,
        STAGE_DECODE = 2'b01,
        STAGE_EXECUTE = 2'b10
    } pipeline_stage_t;
    
    // Pipeline state
    reg pipeline_active;
    reg [3:0] pc;  // Program counter
    
    // Pipeline registers - 3 stages
    reg [7:0] if_id_instruction;    // Fetch -> Decode
    reg [3:0] if_id_pc;
    reg       if_id_valid;
    
    reg [7:0] id_ex_instruction;    // Decode -> Execute  
    reg [3:0] id_ex_pc;
    reg       id_ex_valid;
    reg [1:0] id_ex_opcode;
    reg [1:0] id_ex_rd, id_ex_rs, id_ex_rt;
    reg [DATA_WIDTH-1:0] id_ex_reg_data1, id_ex_reg_data2;
    
    // Hazard detection
    reg data_hazard;
    reg memory_stall;
    reg pipeline_flush;
    
    // Register file interface
    wire [DATA_WIDTH-1:0] reg_read_data1, reg_read_data2;
    reg reg_write_en;
    reg [1:0] reg_write_addr;
    reg [DATA_WIDTH-1:0] reg_write_data;
    
    // ALU interface
    reg [DATA_WIDTH-1:0] alu_a, alu_b;
    wire [DATA_WIDTH-1:0] alu_result;
    
    // SIMD program - each thread processes different data elements
    reg [7:0] program [15:0];
    initial begin
        case (THREAD_ID)
            0: begin  // Thread 0: Process elements 0,4 -> result[0]
                program[0] = {OP_LOAD,  2'b00, 2'b11, 2'b00};  // LOAD R0, [R3+0] 
                program[1] = {OP_LOAD,  2'b01, 2'b11, 2'b00};  // LOAD R1, [R3+4]
                program[2] = {OP_ADD,   2'b10, 2'b00, 2'b01};  // ADD R2, R0, R1
                program[3] = {OP_STORE, 2'b10, 2'b11, 2'b00};  // STORE [R3+16], R2
                program[4] = {OP_HALT,  2'b00, 2'b00, 2'b00};  // HALT
            end
            1: begin  // Thread 1: Process elements 1,5 -> result[1]
                program[0] = {OP_LOAD,  2'b00, 2'b11, 2'b01};  // LOAD R0, [R3+1]
                program[1] = {OP_LOAD,  2'b01, 2'b11, 2'b01};  // LOAD R1, [R3+5] 
                program[2] = {OP_ADD,   2'b10, 2'b00, 2'b01};  // ADD R2, R0, R1
                program[3] = {OP_STORE, 2'b10, 2'b11, 2'b01};  // STORE [R3+17], R2
                program[4] = {OP_HALT,  2'b00, 2'b00, 2'b00};  // HALT
            end
            2: begin  // Thread 2: Process elements 2,6 -> result[2]
                program[0] = {OP_LOAD,  2'b00, 2'b11, 2'b10};  // LOAD R0, [R3+2]
                program[1] = {OP_LOAD,  2'b01, 2'b11, 2'b10};  // LOAD R1, [R3+6]
                program[2] = {OP_ADD,   2'b10, 2'b00, 2'b01};  // ADD R2, R0, R1
                program[3] = {OP_STORE, 2'b10, 2'b11, 2'b10};  // STORE [R3+18], R2
                program[4] = {OP_HALT,  2'b00, 2'b00, 2'b00};  // HALT
            end
            3: begin  // Thread 3: Process elements 3,7 -> result[3]
                program[0] = {OP_LOAD,  2'b00, 2'b11, 2'b11};  // LOAD R0, [R3+3]
                program[1] = {OP_LOAD,  2'b01, 2'b11, 2'b11};  // LOAD R1, [R3+7]
                program[2] = {OP_ADD,   2'b10, 2'b00, 2'b01};  // ADD R2, R0, R1
                program[3] = {OP_STORE, 2'b10, 2'b11, 2'b11};  // STORE [R3+19], R2
                program[4] = {OP_HALT,  2'b00, 2'b00, 2'b00};  // HALT
            end
        endcase
    end
    
    // Hazard detection logic
    always_comb begin
        data_hazard = 1'b0;
        
        // Check for RAW hazards between decode and execute stages
        if (id_ex_valid && if_id_valid) begin
            // Check if decode stage reads from register written by execute stage
            if ((id_ex_opcode == OP_LOAD || id_ex_opcode == OP_ADD) &&
                (if_id_instruction[5:4] == id_ex_rd || if_id_instruction[3:2] == id_ex_rd)) begin
                data_hazard = 1'b1;
            end
        end
    end
    
    // Pipeline control
    always @(posedge clk) begin
        if (reset) begin
            // Reset all pipeline stages
            if_id_valid <= 1'b0;
            id_ex_valid <= 1'b0;
            pc <= 4'h0;
            done <= 1'b0;
            active <= 1'b0;
            pipeline_active <= 1'b0;
            pipeline_stall <= 1'b0;
            instruction_valid <= 1'b0;
            mem_read_en <= 1'b0;
            mem_write_en <= 1'b0;
            reg_write_en <= 1'b0;
        end
        else begin
            // Default values
            pipeline_stall <= data_hazard || memory_stall;
            instruction_valid <= id_ex_valid && !pipeline_stall;
            
            if (start && !pipeline_active) begin
                pipeline_active <= 1'b1;
                active <= 1'b1;
                pc <= 4'h0;
                done <= 1'b0;
            end
            
            if (pipeline_active) begin
                // Stage 3: Execute/Memory/Writeback
                if (id_ex_valid && !data_hazard) begin
                    case (id_ex_opcode)
                        OP_LOAD: begin
                            mem_addr <= id_ex_rs + THREAD_ID;  // Thread-specific offset
                            mem_read_en <= 1'b1;
                            memory_stall <= 1'b1;  // Stall for memory access
                            
                            // Writeback next cycle
                            reg_write_en <= 1'b1;
                            reg_write_addr <= id_ex_rd;
                            reg_write_data <= mem_read_data;
                        end
                        
                        OP_ADD: begin
                            alu_a <= id_ex_reg_data1;
                            alu_b <= id_ex_reg_data2;
                            
                            // Writeback
                            reg_write_en <= 1'b1;
                            reg_write_addr <= id_ex_rd;
                            reg_write_data <= alu_result;
                        end
                        
                        OP_STORE: begin
                            mem_addr <= 5'd16 + THREAD_ID;  // Results start at address 16
                            mem_write_data <= id_ex_reg_data1;
                            mem_write_en <= 1'b1;
                            memory_stall <= 1'b1;
                        end
                        
                        OP_HALT: begin
                            done <= 1'b1;
                            active <= 1'b0;
                            pipeline_active <= 1'b0;
                        end
                    endcase
                end
                else begin
                    mem_read_en <= 1'b0;
                    mem_write_en <= 1'b0;
                    reg_write_en <= 1'b0;
                    memory_stall <= 1'b0;
                end
                
                // Stage 2: Decode (if not stalled)
                if (!data_hazard && !memory_stall) begin
                    id_ex_instruction <= if_id_instruction;
                    id_ex_pc <= if_id_pc;
                    id_ex_valid <= if_id_valid;
                    id_ex_opcode <= if_id_instruction[7:6];
                    id_ex_rd <= if_id_instruction[5:4];
                    id_ex_rs <= if_id_instruction[3:2];
                    id_ex_rt <= if_id_instruction[1:0];
                    id_ex_reg_data1 <= reg_read_data1;
                    id_ex_reg_data2 <= reg_read_data2;
                end
                
                // Stage 1: Fetch (if not stalled)
                if (!data_hazard && !memory_stall && pc < 5) begin
                    if_id_instruction <= program[pc];
                    if_id_pc <= pc;
                    if_id_valid <= 1'b1;
                    pc <= pc + 1'b1;
                end
                else if (pc >= 5) begin
                    if_id_valid <= 1'b0;  // No more instructions
                end
            end
        end
    end
    
    // Register file with special GPU registers
    gpu_register_file #(
        .THREAD_ID(THREAD_ID),
        .BLOCK_ID(BLOCK_ID),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_REGISTERS(NUM_REGISTERS)
    ) reg_file (
        .clk(clk),
        .reset(reset),
        .read_addr1(if_id_instruction[3:2]),  // rs
        .read_addr2(if_id_instruction[1:0]),  // rt
        .read_data1(reg_read_data1),
        .read_data2(reg_read_data2),
        .write_en(reg_write_en),
        .write_addr(reg_write_addr),
        .write_data(reg_write_data),
        .debug_reg0(debug_reg0)
    );
    
    // ALU
    alu #(
        .DATA_WIDTH(DATA_WIDTH)
    ) alu_inst (
        .a(alu_a),
        .b(alu_b),
        .result(alu_result)
    );

endmodule

`default_nettype wire
