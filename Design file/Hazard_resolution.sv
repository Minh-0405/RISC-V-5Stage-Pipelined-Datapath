`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31

// inst. are 32 bits in RV32IM
`define INST_SIZE 31

// RV opcodes are 7 bits
`define OPCODE_SIZE 6

module choice_operand (
        input  logic [1:0] op_control,
        input  logic [`REG_SIZE:0] rs,
        input  logic [`REG_SIZE:0] mem_forward,
        input  logic [`REG_SIZE:0] wb_forward,
        output logic [`REG_SIZE:0] operand
);
    // control: 0x: rs ; 10: mem ; 11: wb
    logic [`REG_SIZE:0] forward_op ;
    assign forward_op = (op_control[0])? wb_forward : mem_forward ;
    assign operand = (op_control[1])? forward_op : rs ;
endmodule

module detect_ExForwarding(
        input  logic [1:0] we,  // we[0] = m_we ; we[1] = w_we
        input  logic [4:0] rs1, rs2,
        input  logic [4:0] m_rd, w_rd,
        output logic [1:0] op1_control,
        output logic [1:0] op2_control
);
    // control: 0x: rs ; 10: mem ; 11: wb
    localparam logic [1:0] Rs = 2'b00 ;
    localparam logic [1:0] Mem = 2'b10 ;
    localparam logic [1:0] Wb = 2'b11 ;

    always_comb
    begin
        // op1_control
        if((rs1 == m_rd) && (we[0] == 1) && (m_rd != 0))
            op1_control = Mem ;
        else if((rs1 == w_rd) && (we[1] == 1) && (w_rd != 0))
            op1_control = Wb ;
        else op1_control = Rs ;
        // op2_control
        if((rs2 == m_rd) && (we[0] == 1) && (m_rd != 0))
            op2_control = Mem ;
        else if((rs2 == w_rd) && (we[1] == 1) && (w_rd != 0))
            op2_control = Wb ;
        else op2_control = Rs ;
    end
endmodule

module detect_MemForwarding(
        input  logic w_we,
        input  logic [4:0] w_rd,
        input  logic [4:0] m_rs2,
        output logic control
);
    //control: 0: rs2_data ; 1: Forwarding

    always_comb
    begin
        if((w_we == 1) && (w_rd == m_rs2) && (w_rd != 0))
            control = 1'b1 ;
        else control = 1'b0 ;
    end
endmodule

module load_stall(
        input  logic is_load,
        input  logic [4:0] rs1, rs2,
        input  logic [4:0] ex_rd,
        output logic stall
);
    always_comb
    begin
        if((is_load) && ((ex_rd == rs1) || (ex_rd == rs2)))
            stall = 1'b1 ;
        else stall = 1'b0 ;
    end
endmodule
