`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31

// inst. are 32 bits in RV32IM
`define INST_SIZE 31

// RV opcodes are 7 bits
`define OPCODE_SIZE 6

module RegFile (
        input  logic [        4:0] rd,
        input  logic [`REG_SIZE:0] rd_data,
        input  logic [        4:0] rs1,
        output logic [`REG_SIZE:0] rs1_data,
        input  logic [        4:0] rs2,
        output logic [`REG_SIZE:0] rs2_data,
        input  logic               clk,
        input  logic               we,
        input  logic               rst
);
    localparam int NumRegs = 32 ;
    logic [`REG_SIZE:0] regs [NumRegs];

    always_ff @(posedge clk)
    begin
        if(rst)
        begin
            for(int i=0 ; i <= `REG_SIZE ; i++)
                regs[i] <= 0 ;
        end
        else
        begin
            if(we & (|rd)) regs[rd] <= rd_data ;
        end
    end
    always_comb // Read assyn -> read the newest data to X pipelined
    begin
        rs1_data = regs[rs1] ;
        rs2_data = regs[rs2] ;
    end
endmodule

module Imm_Gen
    import riscv_pkg::* ; // similar to using namespace std
(
        input  logic [`INST_SIZE:0] inst,
        output logic [`REG_SIZE:0]  imm
);
    // setup for I, S, B & J type instructions
    // I - short immediates and loads
    logic [11:0] imm_i;
    assign imm_i = inst[31:20];

    // S - stores
    logic [11:0] imm_s;
    assign imm_s = {inst[31:25], inst[11:7]};

    // B - conditionals
    logic [12:0] imm_b;
    assign {imm_b[12], imm_b[10:1], imm_b[11], imm_b[0]} = {inst[31:25], inst[11:7], 1'b0};

    // J - unconditional jumps
    logic [20:0] imm_j;
    assign {imm_j[20], imm_j[10:1], imm_j[11], imm_j[19:12], imm_j[0]} = {inst[31:12], 1'b0};

    // U - lui
    logic [`REG_SIZE:0] imm_u;
    assign imm_u = {inst[31:12], 12'b0};

    logic [`REG_SIZE:0] imm_i_sext ;
    logic [`REG_SIZE:0] imm_s_sext ;
    logic [`REG_SIZE:0] imm_b_sext ;
    logic [`REG_SIZE:0] imm_j_sext ;
    assign imm_i_sext = {{20{imm_i[11]}}, imm_i[11:0]};
    assign imm_s_sext = {{20{imm_s[11]}}, imm_s[11:0]};
    assign imm_b_sext = {{19{imm_b[12]}}, imm_b[12:0]};
    assign imm_j_sext = {{11{imm_j[20]}}, imm_j[20:0]};

    always_comb
    begin
        unique case (inst[6:0])
        OpLui:      imm = imm_u ;
        OpRegImm:   imm = imm_i_sext ;
        OpStore:    imm = imm_s_sext ;
        OpLoad:     imm = imm_i_sext ;
        OpBranch:   imm = imm_b_sext ;
        OpJal:      imm = imm_j_sext ;
        OpJalr:     imm = imm_i_sext ;
        default: imm = 32'b0 ;
        endcase
    end
endmodule

module Control_unit
    import riscv_pkg::* ;
(
        input  logic [`REG_SIZE:0] inst,
        output logic [1:0] store_control,
        output logic [2:0] load_control,
        output logic is_div,
        output logic is_lui,
        output logic rd_we,
        output logic [1:0] rd_in_choose,
        output logic [1:0] alu_op,
        output logic alu_operand2,
        output logic [1:0] inst_branch,
        output logic [1:0] jump,
        output logic invalid_decode,
        output logic halt
);
    // alu_op
    localparam logic [1:0] RegReg = 2'b00 ;
    localparam logic [1:0] RegImm = 2'b01 ;
    localparam logic [1:0] Branch = 2'b10 ;
    localparam logic [1:0] StoreLoad = 2'b11 ;

    // alu_operand2
    localparam logic Imme = 1'b1 ;
    localparam logic Rs2 = 1'b0 ;

    // rd_in_choose
    localparam logic [1:0] AluOut = 2'b00 ;
    localparam logic [1:0] Dmem   = 2'b01 ;
    localparam logic [1:0] Ra     = 2'b10 ; //return address from JAL or JALR

    // store_control
    // detect the type of store

    // load_control
    // first bit 1 for unsigned; remain bit stand for number of bytes load

    // branch
    // first bit is for detect type; second bit is for detect if it is a branch inst

    //jump
    localparam logic [1:0] Jal  = 2'b01 ;
    localparam logic [1:0] Jalr = 2'b11 ;

    always_comb
    begin
        //default
        halt = 1'b0 ;
        invalid_decode = 1'b0 ;
        store_control = 2'b11 ;
        load_control = 3'b0 ;
        is_div = 1'b0 ;
        is_lui = 1'b0 ;
        rd_we = 1'b0 ;
        rd_in_choose = AluOut ;
        inst_branch = 2'b0 ;
        jump = 2'b0 ;
        alu_op = RegReg ;
        alu_operand2 = Imme ;

        unique case(inst[6:0])
            OpLui:      begin
                is_lui = 1'b1 ;
                rd_in_choose = AluOut ;
                rd_we = 1'b1 ;
            end
            OpRegReg:   begin
                alu_op = RegReg ;
                alu_operand2 = Rs2 ;
                rd_in_choose = AluOut ;
                rd_we = 1'b1 ;
                is_div = (inst[25] == 1) ;
            end
            OpRegImm:   begin
                alu_op = RegImm ;
                alu_operand2 = Imme ;
                rd_in_choose = AluOut ;
                rd_we = 1'b1 ;
            end
            OpBranch:   begin
                alu_op = Branch ;
                alu_operand2 = Rs2 ;
                inst_branch = {inst[12], 1'b1} ;
            end
            OpJal:      begin
                alu_op = RegReg ;
                alu_operand2 = Rs2 ;
                rd_in_choose = Ra ;
                rd_we = 1'b1 ;
                jump = Jal ;
            end
            OpJalr:     begin
                alu_op = RegReg ;
                alu_operand2 = Imme ;
                rd_in_choose = Ra ;
                rd_we = 1'b1 ;
                jump = Jalr ;
            end
            OpStore:    begin
                store_control = inst[13:12] ;
                alu_op = StoreLoad ;
                alu_operand2 = Imme ;
            end
            OpLoad:     begin
                alu_op = StoreLoad ;
                alu_operand2 = Imme ;
                load_control = inst[14:12] ;
                rd_in_choose = Dmem ;
                rd_we = 1'b1 ;
            end
            OpEnviron:  begin
                halt = 1'b1 ;
            end
            default:    begin
                invalid_decode = 1'b1 ;
            end
        endcase
    end
endmodule

module x_pipelined (
        input  logic clk, rst, nops,
        input  logic [`REG_SIZE:0] i_rs1_data,
        input  logic [`REG_SIZE:0] i_rs2_data,
        input  logic [`REG_SIZE:0] i_imm_data,
        input  logic [3:0]         i_alu_control,
        input  logic [4:0]         i_rd,
        input  logic [4:0]         i_rs1,
        input  logic [4:0]         i_rs2,
        input  logic [`INST_SIZE:0]i_pc,
        output logic [`REG_SIZE:0] o_rs1_data,
        output logic [`REG_SIZE:0] o_rs2_data,
        output logic [`REG_SIZE:0] o_imm_data,
        output logic [3:0]         o_alu_control,
        output logic [4:0]         o_rd,
        output logic [4:0]         o_rs1,
        output logic [4:0]         o_rs2,
        output logic [`INST_SIZE:0]o_pc
);
    always_ff @(posedge clk)
    begin
        if(rst)
        begin
            o_rs1_data     <= 32'b0 ;
            o_rs2_data     <= 32'b0 ;
            o_imm_data     <= 32'b0 ;
            o_alu_control  <= 4'b0 ;
            o_rd           <= 5'b0 ;
            o_rs1          <= 5'b0 ;
            o_rs2          <= 5'b0 ;
            o_pc           <= 32'b0 ;
        end
        else
        begin
            if(!nops)
            begin
                o_rs1_data     <= i_rs1_data ;
                o_rs2_data     <= i_rs2_data ;
            end
            o_imm_data     <= i_imm_data ;
            o_alu_control  <= i_alu_control ;
            o_rd           <= i_rd ;
            o_rs1           <= i_rs1 ;
            o_rs2           <= i_rs2 ;
            o_pc           <= i_pc ;
        end
    end
endmodule

module x_control_pipelined (
        input  logic clk, rst, nops,
        input  logic [1:0] i_store_control,
        input  logic [2:0] i_load_control,
        input  logic       i_is_div,
        input  logic       i_is_lui,
        input  logic       i_rd_we,
        input  logic [1:0] i_rd_in_choose,
        input  logic [1:0] i_alu_op,
        input  logic       i_alu_operand2,
        input  logic [1:0] i_inst_branch,
        input  logic [1:0] i_inst_jump,
        output logic [1:0] o_store_control,
        output logic [2:0] o_load_control,
        output logic       o_is_div,
        output logic       o_is_lui,
        output logic       o_rd_we,
        output logic [1:0] o_rd_in_choose,
        output logic [1:0] o_alu_op,
        output logic       o_alu_operand2,
        output logic [1:0] o_inst_branch,
        output logic [1:0] o_inst_jump
);
    always_ff @(posedge clk)
    begin
        if(rst || nops)
        begin
            o_store_control <= 2'b11 ;
            o_load_control  <= 3'b0 ;
            o_is_div        <= 1'b0 ;
            o_is_lui        <= 1'b0 ;
            o_rd_we         <= 1'b0 ;
            o_rd_in_choose  <= 2'b0 ;
            o_alu_op        <= 2'b0 ;
            o_alu_operand2  <= 1'b0 ;
            o_inst_branch   <= 2'b0 ;
            o_inst_jump     <= 2'b0 ;
        end
        else
        begin
            o_store_control <= i_store_control ;
            o_load_control  <= i_load_control ;
            o_is_div        <= i_is_div ;
            o_is_lui        <= i_is_lui ;
            o_rd_we         <= i_rd_we ;
            o_rd_in_choose  <= i_rd_in_choose ;
            o_alu_op        <= i_alu_op ;
            o_alu_operand2  <= i_alu_operand2 ;
            o_inst_branch   <= i_inst_branch ;
            o_inst_jump     <= i_inst_jump ;
        end
    end
endmodule

