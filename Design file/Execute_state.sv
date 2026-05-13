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

module ALUs (
        input  logic rst,
        input  logic [`REG_SIZE:0] rs1, rs2,
        input  logic inst_type, // 0: R-type ; 1: I-type
        input  logic [3:0] control, // control[3] = inst[30], remain 3 bits are funct3
        output logic [`REG_SIZE:0] alu_out
);
    logic sub_control ;
    logic sra_control ;
    assign sub_control = ~inst_type && control[3] ;
    assign sra_control = control[3] ;

    logic [`REG_SIZE:0] data2;
    logic [`REG_SIZE:0] adder_out;
    logic cout;
    assign data2 = sub_control? ~(rs2) : rs2 ;
    cla unit(
        .a(rs1),
        .b(data2),
        .cin(sub_control),
        .sum(adder_out),
        .carry_out(cout)
    );

    logic [`REG_SIZE:0] alu_add_sub ;
    logic [`REG_SIZE:0] alu_sll ;
    logic [`REG_SIZE:0] alu_slt ;
    logic [`REG_SIZE:0] alu_sltu ;
    logic [`REG_SIZE:0] alu_xor ;
    logic [`REG_SIZE:0] alu_sr ;
    logic [`REG_SIZE:0] alu_or ;
    logic [`REG_SIZE:0] alu_and ;
    always_comb
    begin
        alu_add_sub = adder_out ;
        alu_sll = rs1 << {rs2[4:0]} ;
        alu_slt = $signed(rs1) < $signed(rs2) ? 32'd1 : 32'b0 ;
        alu_sltu = rs1 < rs2 ? 32'd1 : 32'b0 ;
        alu_xor = rs1 ^ rs2 ;
        alu_sr = sra_control? ((rs1 >> rs2[4:0]) | ({32{rs1[31]}} << (32-rs2[4:0]))) :
                                    (rs1 >> rs2[4:0]) ;
        alu_or = rs1 | rs2 ;
        alu_and = rs1 & rs2 ;
    end

    always_comb
    begin
    unique case (control[2:0])
        3'b000:  begin // ADD, SUB
            alu_out = alu_add_sub ;
        end
        3'b001:  begin // SLL
            alu_out = alu_sll ;
        end
        3'b010:  begin // SLT
            alu_out = alu_slt ;
        end
        3'b011:  begin // SLTU
            alu_out = alu_sltu ;
        end
        3'b100:  begin // XOR
            alu_out = alu_xor ;
        end
        3'b101:  begin // SRL, SRA
            alu_out = alu_sr ;
        end
        3'b110:  begin // OR
            alu_out = alu_or ;
        end
        3'b111:  begin //AND
            alu_out = alu_and ;
        end
        default: alu_out = 32'b0 ;
    endcase
    end
endmodule

module M_ALUs (
       input  logic clk, rst,
       input  logic [`REG_SIZE:0] rs1, rs2,
       input  logic [2:0] control,
       output logic [`REG_SIZE:0] quot_out,
       output logic [`REG_SIZE:0] rem_out,
       output logic [(`REG_SIZE)*2+1:0] mul_out,
       output logic [2:0] m_alu_choose
);
   logic [`REG_SIZE:0] pos_rs1, pos_rs2 ;
   transform_pos #(.SIZE(32)) pos_op1 (
       .in(rs1),
       .out(pos_rs1)
   );
   transform_pos #(.SIZE(32)) pos_op2 (
       .in(rs2),
       .out(pos_rs2)
   );

   logic [`REG_SIZE:0] choice_dividend ;
   logic [`REG_SIZE:0] choice_divisor ;
   assign choice_dividend = ((control[0] == 0) & (rs1[31] == 1))? pos_rs1 : rs1 ;
   assign choice_divisor = ((control[0] == 0) & (rs2[31] == 1))? pos_rs2 : rs2 ;

   logic signed [`REG_SIZE+1:0] choice_mul1 ;
   logic signed [`REG_SIZE+1:0] choice_mul2 ;
   logic signed [(`REG_SIZE+1)*2+1:0] signed_mul ;
   assign choice_mul1 = (control[1:0] == 2'b11)? $signed({1'b0, rs1}) : $signed(rs1) ;
   assign choice_mul2 = ((control[1] == 1))? $signed({1'b0, rs2}) : $signed(rs2) ;
   assign signed_mul = choice_mul1 * choice_mul2 ;
   assign mul_out = signed_mul[(`REG_SIZE+1)*2+1:0] ;

   localparam logic [2:0] Mul = 3'b000 ;
   localparam logic [2:0] MulH = 3'b001 ;
   localparam logic [2:0] Quo = 3'b100 ;
   localparam logic [2:0] NegQuo = 3'b101 ;
   localparam logic [2:0] Rem = 3'b110 ;
   localparam logic [2:0] NegRem = 3'b111 ;

   logic [2:0] tmp_choose ;
   always_comb
   begin
   unique case (control)
       3'b000: //MUL
           tmp_choose = Mul ;
       3'b001: //MULH
           tmp_choose = MulH ;
       3'b010: //MULHSU
           tmp_choose = MulH ;
       3'b011: //MULHU
           tmp_choose = MulH ;
       3'b100: //DIV
           tmp_choose = (rs1[31] ^ rs2[31])? NegQuo : Quo ;
       3'b101: //DIVU
           tmp_choose = Quo ;
       3'b110: //REM
           tmp_choose = (rs1[31] == 1)? NegRem : Rem ;
       3'b111: //REMU
           tmp_choose = Rem ;
       default: tmp_choose = Mul ;
   endcase
   end

    logic [2:0] delay_div_choose ;
   DividerUnsignedPipelined unit (
       .clk(clk), .rst(rst),
       .i_signedchoose(tmp_choose),
       .i_dividend(choice_dividend),
       .i_divisor(choice_divisor),
       .o_remainder(rem_out),
       .o_quotient(quot_out),
       .o_signedchoose(delay_div_choose)
   );

   assign m_alu_choose = (delay_div_choose[2] == 1)? delay_div_choose : tmp_choose ;
endmodule

module m_pipelined(
        input clk, rst,
        input  logic [`REG_SIZE:0] i_pc_branch,
        input  logic [`REG_SIZE:0] i_aluout,
        input  logic [`REG_SIZE:0] i_quotient,
        input  logic [`REG_SIZE:0] i_remainder,
        input  logic [(`REG_SIZE)*2+1:0] i_mulout,
        input  logic [2:0]         i_m_aluout_choose,
        input  logic [1:0]         i_load_byte,
        input  logic [`REG_SIZE:0] i_lui_data,
        input  logic [4:0]         i_rs2_addr,
        input  logic [4:0]         i_rd,
        input  logic [`INST_SIZE:0]i_ra,
        output logic [`REG_SIZE:0] o_pc_branch,
        output logic [`REG_SIZE:0] o_aluout,
        output logic [`REG_SIZE:0] o_quotient,
        output logic [`REG_SIZE:0] o_remainder,
        output logic [(`REG_SIZE)*2+1:0] o_mulout,
        output logic [2:0]         o_m_aluout_choose,
        output logic [1:0]         o_load_byte,
        output logic [`REG_SIZE:0] o_lui_data,
        output logic [4:0]         o_rs2_addr,
        output logic [4:0]         o_rd,
        output logic [`INST_SIZE:0]o_ra
);
    (* max_fanout = 16 *) logic [`REG_SIZE:0] aluout_reg ;
    (* max_fanout = 16 *) logic [4:0] rd_reg ;

    always_ff @(posedge clk)
    begin
        if(rst)
        begin
            o_pc_branch       <= 32'b0 ;
            aluout_reg        <= 32'b0 ;
            o_load_byte       <= 2'b0 ;
            o_lui_data        <= 32'b0 ;
            o_rs2_addr        <= 5'b0 ;
            rd_reg              <= 5'b0 ;
            o_ra              <= 32'b0 ;
            o_quotient        <= 32'b0 ;
            o_remainder       <= 32'b0 ;
            o_mulout          <= 32'b0 ;
            o_m_aluout_choose <= 3'b0 ;
        end
        else
        begin
            o_pc_branch       <= i_pc_branch ;
            aluout_reg        <= i_aluout ;
            o_load_byte       <= i_load_byte ;
            o_lui_data        <= i_lui_data ;
            o_rs2_addr        <= i_rs2_addr ;
            rd_reg              <= i_rd ;
            o_ra              <= i_ra ;
            o_quotient        <= i_quotient ;
            o_remainder       <= i_remainder ;
            o_mulout          <= i_mulout ;
            o_m_aluout_choose <= i_m_aluout_choose ;
        end
    end
    assign o_aluout = aluout_reg ;
    assign o_rd = rd_reg ;
endmodule

module m_control_pipelined(
        input  logic clk, rst,
        input  logic nops,
        input  logic is_div,
        input  logic is_mul,
        input  div_control_t div_ctrl,
        input  logic i_is_lui,
        input  logic i_b_cond,
        input  logic i_jump,
        input  logic i_branch,
        input  logic [2:0] i_load_control,
        input  logic       i_rd_we,
        input  logic [1:0] i_rd_in_choose,
        output logic div_mul,
        output logic o_is_lui,
        output logic o_b_cond,
        output logic o_jump,
        output logic o_branch,
        output logic [2:0] o_load_control,
        output logic       o_rd_we,
        output logic [1:0] o_rd_in_choose
);
    (* max_fanout = 16 *) logic [2:0] load_control_reg ;
    (* max_fanout = 16 *) logic [4:0] rd_we_reg ;

    always_ff @(posedge clk)
    begin
        if(rst | is_div | nops)
        begin
            o_is_lui       <= 1'b0 ;
            o_b_cond       <= 1'b0 ;
            o_jump         <= 1'b0 ;
            o_branch       <= 1'b0 ;
            load_control_reg <= 3'b0 ;
            rd_we_reg        <= 1'b0 ;
            o_rd_in_choose <= 2'b0 ;
            div_mul       <= 1'b0 ;
        end
        else
        begin
            if(div_ctrl.done)
            begin
                o_is_lui       <= 1'b0 ;
                o_b_cond       <= 1'b0 ;
                o_jump         <= 1'b0 ;
                o_branch       <= 1'b0 ;
                load_control_reg <= 3'b0 ;
                rd_we_reg        <= div_ctrl.rd_we ;
                o_rd_in_choose <= div_ctrl.rd_in_choose ;
            end
            else
            begin
                o_is_lui       <= i_is_lui ;
                load_control_reg <= i_load_control ;
                rd_we_reg        <= i_rd_we ;
                o_rd_in_choose <= i_rd_in_choose ;
                o_b_cond       <= i_b_cond ;
                o_jump         <= i_jump ;
                o_branch       <= i_branch ;
            end
            div_mul <= (div_ctrl.done | is_mul)? 1'b1 : 1'b0 ;
        end
    end
    assign o_load_control = load_control_reg ;
    assign o_rd_we = rd_we_reg ;
endmodule
