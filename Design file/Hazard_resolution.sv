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
    // control: 0x: rs ; 10: mem ; 01: wb
    logic [`REG_SIZE:0] forward_op ;
    assign forward_op = (op_control[0])? wb_forward : mem_forward ;
    assign operand = (|op_control)? forward_op : rs ;
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
    localparam logic [1:0] Wb = 2'b01 ;


    wire m_forward_op1 = (rs1 == m_rd) && (we[0] == 1) && (m_rd != 0) ;
    wire w_forward_op1 = (rs1 == w_rd) && (we[1] == 1) && (w_rd != 0) ;
    wire m_forward_op2 = (rs2 == m_rd) && (we[0] == 1) && (m_rd != 0) ;
    wire w_forward_op2 = (rs2 == w_rd) && (we[1] == 1) && (w_rd != 0) ;
    logic [1:0] case_op1, case_op2 ;
    assign case_op1 = {m_forward_op1, w_forward_op1} ;
    assign case_op2 = {m_forward_op2, w_forward_op2} ;
    always_comb
    begin
        unique case(case_op1)
            2'b00: op1_control = Rs ;
            2'b10: op1_control = Mem ;
            2'b01: op1_control = Wb ;
            2'b11: op1_control = Mem ;
            default: op1_control = Rs ;
        endcase
        unique case(case_op2)
            2'b00: op2_control = Rs ;
            2'b10: op2_control = Mem ;
            2'b01: op2_control = Wb ;
            2'b11: op2_control = Mem ;
            default: op2_control = Rs ;
        endcase
    end
endmodule

module load_stall(
        input  logic is_load,
        input  logic [4:0] rs1, rs2,
        input  logic [4:0] ex_rd,
        output logic stall
);
    assign stall = (is_load) && ((ex_rd == rs1) || (ex_rd == rs2)) ;
endmodule
