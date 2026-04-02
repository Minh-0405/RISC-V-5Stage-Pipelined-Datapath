`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31

// inst. are 32 bits in RV32IM
`define INST_SIZE 31

// RV opcodes are 7 bits
`define OPCODE_SIZE 6

//`include "DividerUnsignedPipelined.sv"
//`include "cla.sv"

// Prepare for MUL DIV operation
module transform_2_compliment #(
   parameter int SIZE = 32
)
(
       input logic  [SIZE-1:0] in,
       output logic [SIZE-1:0] out
);
   logic [SIZE-1:0] inverse_in ;
   assign inverse_in = ~in ;
   assign out = inverse_in + 1 ;
endmodule

module transform_pos #(
   parameter int SIZE = 32
)
(
       input logic  [SIZE-1:0] in,
       output logic [SIZE-1:0] out
);
   logic [SIZE-1:0] tmp ;
   assign tmp = in - 1 ;
   assign out = ~tmp ;
endmodule

module alu_control(
    input [1:0] opcode,
    input [3:0] control, // {inst[30], inst[14:12]}
    output logic [2:0] operation,
    output logic sub_control,
    output logic sra_control,
    output logic branch_control
);
    localparam logic [1:0] RegReg = 2'b0 ;
    localparam logic [1:0] RegImm = 2'b01 ;
    localparam logic [1:0] Branch = 2'b10 ;
    localparam logic [1:0] StoreLoad = 2'b11 ;

    always_comb
    begin
        //default
        operation = 3'b0 ;
        sub_control = 1'b0 ;
        sra_control = 1'b0 ;
        branch_control = 1'b0 ;

        unique case(opcode)
            RegReg:        begin
                operation = control[2:0] ;
                sub_control = control[3] ;
                sra_control = control[3] ;
            end
            RegImm:      begin
                operation = control[2:0] ;
                sra_control = control[3] ;
            end
            Branch:     begin
                if(control[2] == 0) // beq/bne -> sub
                begin
                    operation = 3'b0 ;
                    sub_control = 1'b1 ;
                    branch_control = 1'b0 ;
                end
                else begin // slt
                    operation[0] = control[1] ; // signed control bit
                    operation[2:1] = 2'b01 ;
                    branch_control = 1'b1 ;
                end
            end
            StoreLoad:  begin // add to calculate address
                operation = 3'b0 ;
            end
            default: ;
        endcase
    end
endmodule

module ALUs (
        input  logic rst,
        input  logic [`REG_SIZE:0] rs1, rs2,
        input  logic [2:0] control,
        input  logic sub_control, sra_control, branch_control,
        output logic [`REG_SIZE:0] alu_out,
        output logic b_cond
);

    logic [`REG_SIZE:0] data2;
    logic cin;
    logic [`REG_SIZE:0] adder_out;
    logic cout;
    cla unit(
        .a(rs1),
        .b(data2),
        .cin(cin),
        .sum(adder_out),
        .carry_out(cout)
    );

    logic [`REG_SIZE:0] tmp_out ;
    always_comb
    begin
    //Default
    data2 = rs2 ;
    cin = 1'b0 ;
    unique case (control)
        3'b000:  begin // ADD, SUB
            data2 = sub_control? ~(rs2) : rs2 ;
            cin = sub_control ;
            tmp_out = adder_out;
        end
        3'b001:  begin // SLL
            tmp_out = rs1 << {rs2[4:0]} ;
        end
        3'b010:  begin // SLT
            data2 = ~rs2 ;
            cin = 1'b1 ;
            if ((rs1[31] ^ rs2[31]) & (rs1[31] ^ adder_out[31])) //Detect overflow
                tmp_out = {31'b0, ~adder_out[31]} ;
            else tmp_out = {31'b0, adder_out[31]} ;
        end
        3'b011:  begin // SLTU
            data2 = ~rs2 ;
            cin = 1'b1 ;
            tmp_out = {31'b0, ~cout} ;
        end
        3'b100:  begin // XOR
            tmp_out = rs1 ^ rs2 ;
        end
        3'b101:  begin // SRL, SRA
            tmp_out = sra_control? ((rs1 >> rs2[4:0]) | ({32{rs1[31]}} << (32-rs2[4:0]))) :
                                    (rs1 >> rs2[4:0]) ;
        end
        3'b110:  begin // OR
            tmp_out = rs1 | rs2 ;
        end
        3'b111:  begin //AND
            tmp_out = rs1 & rs2 ;
        end
        default: tmp_out = 32'b0 ;
    endcase
    alu_out = (!rst)? tmp_out : 32'b0 ;
    end

    logic is_zero ;
    assign is_zero = !(|(alu_out)) ;
    assign b_cond = (branch_control)? alu_out[0] : is_zero ;
endmodule

module M_ALUs (
       input  logic clk, rst,
       input  logic [`REG_SIZE:0] rs1, rs2,
       input  logic [2:0] control,
       output logic [`REG_SIZE:0] alu_out,
       output logic illegal_inst
);
   logic [`REG_SIZE:0] pos_rs1, pos_rs2 ;
   transform_pos #(.SIZE(32)) dividend (
       .in(rs1),
       .out(pos_rs1)
   );
   transform_pos #(.SIZE(32)) divisor (
       .in(rs2),
       .out(pos_rs2)
   );

   logic [`REG_SIZE:0] choice_dividend ;
   logic [`REG_SIZE:0] choice_divisor ;
   assign choice_dividend = ((control[0] == 0) & (rs1[31] == 1))? pos_rs1 : rs1 ;
   assign choice_divisor = ((control[0] == 0) & (rs2[31] == 1))? pos_rs2 : rs2 ;

   logic [`REG_SIZE:0] choice_mul1 ;
   logic [`REG_SIZE:0] choice_mul2 ;
   assign choice_mul1 = ((control[1:0] != 2'b11) & (rs1[31] == 1))? pos_rs1 : rs1 ;
   assign choice_mul2 = ((control[1] == 0) & (rs2[31] == 1))? pos_rs2 : rs2 ;

   logic [(`REG_SIZE)*2 + 1:0] mul ;
   assign mul = choice_mul1 * choice_mul2 ;
   logic [(`REG_SIZE)*2 + 1:0] neg_mul ;
   transform_2_compliment #(.SIZE(64)) neg3 (
       .in(mul),
       .out(neg_mul)
   );

   logic [2:0] choose ;
   localparam logic [2:0] Mul = 3'b000 ;
   localparam logic [2:0] NegMul = 3'b001 ;
   localparam logic [2:0] MulH = 3'b010 ;
   localparam logic [2:0] NegMulH = 3'b011 ;
   localparam logic [2:0] Quo = 3'b100 ;
   localparam logic [2:0] NegQuo = 3'b101 ;
   localparam logic [2:0] Rem = 3'b110 ;
   localparam logic [2:0] NegRem = 3'b111 ;
   always_comb
   begin
   unique case (control)
       3'b000: //MUL
           choose = (rs1[31] ^ rs2[31])? NegMul : Mul ;
       3'b001: //MULH
           choose = (rs1[31] ^ rs2[31])? NegMulH : MulH ;
       3'b010: //MULHSU
           choose = (rs1[31] == 1)? NegMulH : MulH ;
       3'b011: //MULHU
           choose = MulH ;
       3'b100: //DIV
           choose = (rs1[31] ^ rs2[31])? NegQuo : Quo ;
       3'b101: //DIVU
           choose = Quo ;
       3'b110: //REM
           choose = (rs1[31] == 1)? NegRem : Rem ;
       3'b111: //REMU
           choose = Rem ;
       default:    choose = Mul ;
   endcase
   end

   logic [2:0] aluout_choose ;
   logic [`REG_SIZE:0] quot, rem ;
   logic [`REG_SIZE:0] neg_quot ;
   logic [`REG_SIZE:0] neg_rem ;
   DividerUnsignedPipelined unit (
       .clk(clk), .rst(rst),
       .i_signedchoose(choose),
       .i_dividend(choice_dividend),
       .i_divisor(choice_divisor),
       .o_remainder(rem),
       .o_quotient(quot),
       .o_signedchoose(aluout_choose)
   );
   transform_2_compliment #(.SIZE(32)) neg1 (
       .in(quot),
       .out(neg_quot)
   );
   transform_2_compliment #(.SIZE(32)) neg2(
       .in(rem),
       .out(neg_rem)
   );

   logic [`REG_SIZE:0] tmp_out ;
   always_comb
   begin
        unique case(aluout_choose)
            Mul:        tmp_out = mul[31:0] ;
            MulH:       tmp_out = mul[63:32] ;
            NegMul:     tmp_out = neg_mul [31:0] ;
            NegMulH:    tmp_out = neg_mul[63:32] ;
            Quo:        tmp_out = quot ;
            Rem:        tmp_out = rem ;
            NegQuo:     tmp_out = neg_quot ;
            NegRem:     tmp_out = neg_rem ;
            default:    tmp_out = 0 ;
        endcase
        alu_out = (!rst)? tmp_out : 32'b0 ;
   end
endmodule

module branch_condition(
        input  logic b_cond,
        input  logic inst_jump,
        input  logic [1:0] inst_branch, //inst_branch[1] = inst[12]
        output logic is_branch
);
    always_comb
    begin
        if(inst_jump) is_branch = 1'b1 ;
        else
        begin
            is_branch = (inst_branch[0] && (inst_branch[1] ^ b_cond))? 1'b1 : 1'b0 ;
        end
    end
endmodule

module m_pipelined(
        input clk, rst,
        input  logic [`REG_SIZE:0] i_aluout,
        input  logic [`REG_SIZE:0] i_rs2_data,
        input  logic [4:0]         i_rs2_addr,
        input  logic [4:0]         i_rd,
        input  logic [`INST_SIZE:0]i_ra,
        output logic [`REG_SIZE:0] o_aluout,
        output logic [`REG_SIZE:0] o_rs2_data,
        output logic [4:0]         o_rs2_addr,
        output logic [4:0]         o_rd,
        output logic [`INST_SIZE:0]o_ra
);
    always_ff @(posedge clk)
    begin
        if(rst)
        begin
            o_aluout      <= 32'b0 ;
            o_rs2_data    <= 32'b0 ;
            o_rs2_addr    <= 5'b0 ;
            o_rd          <= 5'b0 ;
            o_ra          <= 32'b0 ;
        end
        else
        begin
            o_aluout      <= i_aluout ;
            o_rs2_data    <= i_rs2_data ;
            o_rs2_addr    <= i_rs2_addr ;
            o_rd          <= i_rd ;
            o_ra          <= i_ra ;
        end
    end
endmodule

module m_control_pipelined(
        input  logic clk, rst,
        input  logic is_div,
        input  div_control_t div_ctrl,
        input  logic [1:0] i_store_control,
        input  logic [2:0] i_load_control,
        input  logic       i_rd_we,
        input  logic [1:0] i_rd_in_choose,
        output logic [1:0] o_store_control,
        output logic [2:0] o_load_control,
        output logic       o_rd_we,
        output logic [1:0] o_rd_in_choose
);
    always_ff @(posedge clk)
    begin
        if(rst | is_div)
        begin
            o_store_control<= 2'b11 ;
            o_load_control <= 3'b0 ;
            o_rd_we        <= 1'b0 ;
            o_rd_in_choose <= 2'b0 ;
        end
        else
        begin
            if(div_ctrl.done)
            begin
                o_store_control<= 2'b11 ;
                o_load_control <= 3'b0 ;
                o_rd_we        <= div_ctrl.rd_we ;
                o_rd_in_choose <= div_ctrl.rd_in_choose ;
            end
            else
            begin
                o_store_control<= i_store_control ;
                o_load_control <= i_load_control ;
                o_rd_we        <= i_rd_we ;
                o_rd_in_choose <= i_rd_in_choose ;
            end
        end
    end
endmodule
