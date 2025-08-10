`default_nettype none

module core #(
    parameter CORE_ID = 0,
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4,
    parameter NUM_REGISTERS = 4
) (
    input wire clk,
    input wire reset,
    input wire start,
    output reg done,
    
    // Memory interface
    output reg mem_read_en,
    output reg mem_write_en,
    output reg [ADDR_WIDTH-1:0] mem_addr,
    output reg [DATA_WIDTH-1:0] mem_write_data,
    input wire [DATA_WIDTH-1:0] mem_read_data,
    
    // Debug output
    output wire [DATA_WIDTH-1:0] debug_reg0
);

    // Instruction encoding
    localparam [1:0] 
        OP_LOAD  = 2'b00,
        OP_ADD   = 2'b01,
        OP_STORE = 2'b10,
        OP_HALT  = 2'b11;
    
    // State machine
    localparam [2:0]
        STATE_IDLE = 3'b000,
        STATE_FETCH = 3'b001,
        STATE_DECODE = 3'b010,
        STATE_EXECUTE = 3'b011,
        STATE_MEMORY = 3'b100,
        STATE_WRITEBACK = 3'b101,
        STATE_DONE = 3'b111;
    
    reg [2:0] state;
    reg [3:0] pc;  // Program counter
    reg [7:0] instruction;
    
    // Decoded instruction fields
    reg [1:0] opcode;
    reg [1:0] rd, rs, rt;
    
    // Register file interface
    wire [DATA_WIDTH-1:0] reg_read_data1, reg_read_data2;
    reg reg_write_en;
    reg [1:0] reg_write_addr;
    reg [DATA_WIDTH-1:0] reg_write_data;
    
    // ALU interface
    reg [DATA_WIDTH-1:0] alu_a, alu_b;
    wire [DATA_WIDTH-1:0] alu_result;
    
    // Simple program ROM - each core has different starting data
    reg [7:0] program [15:0];
    initial begin
        if (CORE_ID == 0) begin
            // Core 0: Process data[0] and data[1] 
            program[0] = {OP_LOAD,  2'b00, 2'b11, 2'b00};  // LOAD R0, [R3] (R3=0)
            program[1] = {OP_LOAD,  2'b01, 2'b11, 2'b01};  // LOAD R1, [R3+1] 
            program[2] = {OP_ADD,   2'b10, 2'b00, 2'b01};  // ADD R2, R0, R1
            program[3] = {OP_STORE, 2'b10, 2'b11, 2'b00};  // STORE [R3+8], R2
            program[4] = {OP_HALT,  2'b00, 2'b00, 2'b00};  // HALT
        end else begin
            // Core 1: Process data[2] and data[3]
            program[0] = {OP_LOAD,  2'b00, 2'b11, 2'b10};  // LOAD R0, [R3] (R3=2)
            program[1] = {OP_LOAD,  2'b01, 2'b11, 2'b11};  // LOAD R1, [R3+1]
            program[2] = {OP_ADD,   2'b10, 2'b00, 2'b01};  // ADD R2, R0, R1
            program[3] = {OP_STORE, 2'b10, 2'b11, 2'b01};  // STORE [R3+9], R2  
            program[4] = {OP_HALT,  2'b00, 2'b00, 2'b00};  // HALT
        end
    end
    
    // State machine
    always @(posedge clk) begin
        if (reset) begin
            state <= STATE_IDLE;
            pc <= 0;
            done <= 0;
            mem_read_en <= 0;
            mem_write_en <= 0;
            reg_write_en <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (start) begin
                        state <= STATE_FETCH;
                        pc <= 0;
                        done <= 0;
                    end
                end
                
                STATE_FETCH: begin
                    instruction <= program[pc];
                    state <= STATE_DECODE;
                end
                
                STATE_DECODE: begin
                    opcode <= instruction[7:6];
                    rd <= instruction[5:4];
                    rs <= instruction[3:2];
                    rt <= instruction[1:0];
                    state <= STATE_EXECUTE;
                end
                
                STATE_EXECUTE: begin
                    case (opcode)
                        OP_LOAD: begin
                            mem_addr <= (CORE_ID == 0) ? rs : rs + 2;  // Offset for core 1
                            mem_read_en <= 1;
                            state <= STATE_MEMORY;
                        end
                        OP_ADD: begin
                            alu_a <= reg_read_data1;
                            alu_b <= reg_read_data2;
                            state <= STATE_WRITEBACK;
                        end
                        OP_STORE: begin
                            mem_addr <= (CORE_ID == 0) ? 8 : 9;  // Different output locations
                            mem_write_data <= reg_read_data1;
                            mem_write_en <= 1;
                            state <= STATE_MEMORY;
                        end
                        OP_HALT: begin
                            done <= 1;
                            state <= STATE_DONE;
                        end
                    endcase
                end
                
                STATE_MEMORY: begin
                    mem_read_en <= 0;
                    mem_write_en <= 0;
                    state <= STATE_WRITEBACK;
                end
                
                STATE_WRITEBACK: begin
                    if (opcode == OP_LOAD) begin
                        reg_write_en <= 1;
                        reg_write_addr <= rd;
                        reg_write_data <= mem_read_data;
                    end else if (opcode == OP_ADD) begin
                        reg_write_en <= 1;
                        reg_write_addr <= rd;
                        reg_write_data <= alu_result;
                    end else begin
                        reg_write_en <= 0;
                    end
                    
                    pc <= pc + 1;
                    state <= STATE_FETCH;
                end
                
                STATE_DONE: begin
                    // Stay done
                end
            endcase
        end
    end
    
    // Register file
    register_file #(
        .CORE_ID(CORE_ID),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_REGISTERS(NUM_REGISTERS)
    ) reg_file (
        .clk(clk),
        .reset(reset),
        .read_addr1(rs),
        .read_addr2(rt),
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
