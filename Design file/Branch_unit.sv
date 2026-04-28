`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31

// inst. are 32 bits in RV32IM
`define INST_SIZE 31

// RV opcodes are 7 bits
`define OPCODE_SIZE 6

module Branch_condition(
        input logic [2:0] branch_control,
        input logic [`REG_SIZE:0] rs1,
        input logic [`REG_SIZE:0] rs2,
        output logic b_cond
);
    always_comb begin
        unique case(branch_control)
            3'b000: b_cond = (rs1 == rs2) ;
            3'b001: b_cond = (rs1 != rs2) ;
            3'b100: b_cond = ($signed(rs1) < $signed(rs2)) ;
            3'b101: b_cond = ($signed(rs1) >= $signed(rs2)) ;
            3'b110: b_cond = (rs1 < rs2) ;
            3'b111: b_cond = (rs1 >= rs2) ;
            default: b_cond = 1'b0 ;
        endcase
    end
endmodule

module Detect_branch(
        input  logic b_cond,
        input  logic inst_jump,
        input  logic inst_branch,
        output logic is_branch
);
    (* max_fanout = 16 *) logic is_branch_reg ;
    always_comb
    begin
        if(inst_jump) is_branch_reg = 1'b1 ;
        else
        begin
            is_branch_reg = (b_cond && inst_branch)? 1'b1 : 1'b0 ;
        end
    end
    assign is_branch = is_branch_reg ;
endmodule
