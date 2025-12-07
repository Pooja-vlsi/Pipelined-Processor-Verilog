`timescale 1ns/1ps
// ====================
// Testbench (tb)
// ====================
module tb;
    reg clk;
    reg reset;

    pipelined_cpu cpu0 (.clk(clk), .reset(reset));

    integer cycle;
    integer i;

    function [15:0] Rtype;
        input [3:0] opc;
        input [3:0] rd;
        input [3:0] rs;
        input [3:0] rt;
        begin Rtype = {opc, rd, rs, rt}; end
    endfunction

    function [15:0] Itype_load;
        input [3:0] opc;
        input [3:0] rd;
        input [7:0] imm8;
        begin Itype_load = {opc, rd, imm8}; end
    endfunction

    task print_state;
        begin
            $display("Cycle=%0d | IF_pc=%0d IF_instr=0x%h | ID_op=0x%h rd=%0d rs_val=0x%h rt_val=0x%h | EX_alu=0x%h | WB_rd=%0d WB_memR=%b",
                cycle, cpu0.IFID_pc, cpu0.IFID_instr,
                cpu0.IDEX_opcode, cpu0.IDEX_rd, cpu0.IDEX_rs_val, cpu0.IDEX_rt_val,
                cpu0.EXMEM_alu_result, cpu0.MEMWB_rd, cpu0.MEMWB_mem_read);
        end
    endtask

    // clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // main stimulus
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0); // dump all signals

        reset = 1;
        cycle = 0;
        #12;
        reset = 0;

        for (cycle = 0; cycle < 16; cycle = cycle + 1) begin
            @(posedge clk); #1;
            if (cycle < 12) print_state();
        end

        $display("\nFinal Registers (R0–R7):");
        for (i = 0; i < 8; i = i + 1) $write("%0h ", cpu0.regfile[i]);
        $display("\nFinal DM[10]=0x%h DM[11]=0x%h", cpu0.data_mem[10], cpu0.data_mem[11]);
        $display("Simulation finished successfully.");
        $finish;
    end

    // program + data init
    initial begin
        #1;
        cpu0.instr_mem[0] = Itype_load(4'b0010, 4'd1, 8'd10);
        cpu0.instr_mem[1] = Itype_load(4'b0010, 4'd2, 8'd11);
        cpu0.instr_mem[2] = Rtype(4'b0001, 4'd3, 4'd1, 4'd2);
        cpu0.instr_mem[3] = Rtype(4'b0011, 4'd4, 4'd3, 4'd1);
        cpu0.instr_mem[4] = Rtype(4'b0001, 4'd5, 4'd4, 4'd2);

        cpu0.data_mem[10] = 16'h0005;
        cpu0.data_mem[11] = 16'h0003;

        for (i = 0; i < 16; i = i + 1) cpu0.regfile[i] = 16'h0000;
        cpu0.regfile[0] = 16'h0000;
    end
endmodule
