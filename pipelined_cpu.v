`timescale 1ns/1ps
// ====================
// pipelined_cpu (design)
// ====================
module pipelined_cpu (
    input clk,
    input reset
);
    // Program counter
    reg [7:0] pc;

    // Memories and register file
    reg [15:0] instr_mem [0:255];
    reg [15:0] data_mem  [0:255];
    reg [15:0] regfile   [0:15];

    // Pipeline registers
    reg [7:0] IFID_pc;
    reg [15:0] IFID_instr;

    reg [3:0] IDEX_opcode;
    reg [7:0] IDEX_pc;
    reg [3:0] IDEX_rd;
    reg [3:0] IDEX_rs;
    reg [3:0] IDEX_rt;
    reg [15:0] IDEX_rs_val;
    reg [15:0] IDEX_rt_val;
    reg [7:0] IDEX_imm8;
    reg IDEX_reg_write;
    reg IDEX_mem_read;
    reg IDEX_mem_write;
    reg [1:0] IDEX_alu_op;

    reg [7:0] EXMEM_pc;
    reg [15:0] EXMEM_alu_result;
    reg [3:0] EXMEM_rd;
    reg [15:0] EXMEM_rt_val;
    reg EXMEM_reg_write;
    reg EXMEM_mem_read;
    reg EXMEM_mem_write;

    reg [7:0] MEMWB_pc;
    reg [15:0] MEMWB_mem_data;
    reg [15:0] MEMWB_alu_result;
    reg [3:0] MEMWB_rd;
    reg MEMWB_reg_write;
    reg MEMWB_mem_read;

    integer i;

    localparam OPCODE_ADD  = 4'b0001;
    localparam OPCODE_LOAD = 4'b0010;
    localparam OPCODE_SUB  = 4'b0011;

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            instr_mem[i] = 16'h0000;
            data_mem[i]  = 16'h0000;
        end
        for (i = 0; i < 16; i = i + 1) regfile[i] = 16'h0000;
        regfile[0] = 16'h0000;
    end

    wire [15:0] fetched_instr = instr_mem[pc];

    wire [3:0] id_opcode = IFID_instr[15:12];
    wire [3:0] id_rd     = IFID_instr[11:8];
    wire [3:0] id_rs     = IFID_instr[7:4];
    wire [3:0] id_rt     = IFID_instr[3:0];
    wire [7:0] id_imm8   = IFID_instr[7:0];

    always @(posedge clk) begin
        if (reset) begin
            pc <= 8'h00;
            IFID_pc <= 8'h00; IFID_instr <= 16'h0000;
            IDEX_opcode <= 4'h0; IDEX_pc <= 8'h00; IDEX_rd <= 4'h0;
            IDEX_rs <= 4'h0; IDEX_rt <= 4'h0; IDEX_rs_val <= 16'h0000;
            IDEX_rt_val <= 16'h0000; IDEX_imm8 <= 8'h00;
            IDEX_reg_write <= 1'b0; IDEX_mem_read <= 1'b0; IDEX_mem_write <= 1'b0;
            IDEX_alu_op <= 2'b00;
            EXMEM_pc <= 8'h00; EXMEM_alu_result <= 16'h0000; EXMEM_rd <= 4'h0;
            EXMEM_rt_val <= 16'h0000; EXMEM_reg_write <= 1'b0;
            EXMEM_mem_read <= 1'b0; EXMEM_mem_write <= 1'b0;
            MEMWB_pc <= 8'h00; MEMWB_mem_data <= 16'h0000; MEMWB_alu_result <= 16'h0000;
            MEMWB_rd <= 4'h0; MEMWB_reg_write <= 1'b0; MEMWB_mem_read <= 1'b0;
        end else begin
            // WB
            if (MEMWB_reg_write) begin
                if (MEMWB_mem_read) begin
                    if (MEMWB_rd != 0) regfile[MEMWB_rd] <= MEMWB_mem_data;
                end else begin
                    if (MEMWB_rd != 0) regfile[MEMWB_rd] <= MEMWB_alu_result;
                end
            end
            regfile[0] <= 16'h0000;

            // MEM
            MEMWB_pc <= EXMEM_pc;
            MEMWB_rd <= EXMEM_rd;
            MEMWB_reg_write <= EXMEM_reg_write;
            MEMWB_mem_read <= EXMEM_mem_read;
            MEMWB_alu_result <= EXMEM_alu_result;
            if (EXMEM_mem_read) MEMWB_mem_data <= data_mem[EXMEM_alu_result[7:0]];
            else if (EXMEM_mem_write) data_mem[EXMEM_alu_result[7:0]] <= EXMEM_rt_val;
            else MEMWB_mem_data <= 16'h0000;

            // EX
            EXMEM_pc <= IDEX_pc;
            EXMEM_rd <= IDEX_rd;
            EXMEM_rt_val <= IDEX_rt_val;
            EXMEM_reg_write <= IDEX_reg_write;
            EXMEM_mem_read <= IDEX_mem_read;
            EXMEM_mem_write <= IDEX_mem_write;
            case (IDEX_alu_op)
                2'b00: EXMEM_alu_result <= IDEX_rs_val + IDEX_rt_val;
                2'b01: EXMEM_alu_result <= IDEX_rs_val - IDEX_rt_val;
                2'b10: EXMEM_alu_result <= {8'h00, IDEX_imm8};
                default: EXMEM_alu_result <= 16'h0000;
            endcase

            // ID
            IDEX_pc <= IFID_pc;
            IDEX_opcode <= id_opcode;
            IDEX_rd <= id_rd;
            IDEX_rs <= id_rs;
            IDEX_rt <= id_rt;
            IDEX_imm8 <= id_imm8;
            IDEX_rs_val <= regfile[id_rs];
            IDEX_rt_val <= regfile[id_rt];
            IDEX_reg_write <= 1'b0; IDEX_mem_read <= 1'b0; IDEX_mem_write <= 1'b0; IDEX_alu_op <= 2'b00;

            case (id_opcode)
                OPCODE_ADD:  begin IDEX_reg_write <= 1'b1; IDEX_alu_op <= 2'b00; end
                OPCODE_SUB:  begin IDEX_reg_write <= 1'b1; IDEX_alu_op <= 2'b01; end
                OPCODE_LOAD: begin IDEX_reg_write <= 1'b1; IDEX_mem_read <= 1'b1; IDEX_alu_op <= 2'b10; end
                default:     IDEX_reg_
