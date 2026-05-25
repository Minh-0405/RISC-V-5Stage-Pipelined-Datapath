
`timescale 1ns / 1ns

`define REG_SIZE 31

`define DIVIDER_STAGES 33 // first stage for setup, each remaining stage find 1 bit of quotient


// quotient = dividend / divisor

typedef struct packed {
        logic done ; // also is_div value (done means is div shifted 33 stages so division is done)
        logic rd_we ;
        logic [4:0] rd ;
        logic [1:0] rd_in_choose ;
} div_control_t ;

module shift_register(
        input  logic clk,
        input  logic rst,
        input  logic invalid_decode,
        input  logic [4:0] rs1,
        input  logic [4:0] rs2,
        input  logic [4:0] rd,
        input  div_control_t cur_ctrl,
        output div_control_t div_ctrl,
        output logic div_stall
);
    logic [`DIVIDER_STAGES:0] is_stall ;
    div_control_t stage_ctrl [`DIVIDER_STAGES+1] ;

    always_comb
    begin
        for(int i=0 ; i < `DIVIDER_STAGES-1 ; i++)
        begin
            is_stall[i] = ((stage_ctrl[i].done == 1) && (invalid_decode == 0) &&
                                ((rs1 == stage_ctrl[i].rd) || (rs2 == stage_ctrl[i].rd))) ;
        end
        is_stall[`DIVIDER_STAGES-1] = (stage_ctrl[`DIVIDER_STAGES-1].done == 1) ;
    end

    // Case forwarding: div forwarding must forward at stage WB, so need to stall 1 clk if neccessary
    assign is_stall[`DIVIDER_STAGES] = ((stage_ctrl[`DIVIDER_STAGES].done == 1) &&
                                (invalid_decode == 0) &&
                                ((rs1 == stage_ctrl[`DIVIDER_STAGES].rd) ||
                                (rs2 == stage_ctrl[`DIVIDER_STAGES].rd))) ;

    always_ff @(posedge clk)
    begin
        if(rst)
        begin
            for(int i=0 ; i < `DIVIDER_STAGES+1 ; i++)
                stage_ctrl[i] <= 9'b0 ;
        end
        else
        begin
            // ctrl of div inst will be shifted to create the delay
            if(!(|is_stall) && (cur_ctrl.done == 1))
                stage_ctrl[0] <= cur_ctrl ;
            else stage_ctrl[0] <= 9'b0 ;
            for(int i=1 ; i < `DIVIDER_STAGES+1 ; i++)
            begin
                // check if rd of following is the same as div above
                // -> flush div inst (if div not finish)
                if(rd == stage_ctrl[i-1].rd) stage_ctrl[i] <= 9'b0 ;
                else stage_ctrl[i] <= stage_ctrl[i-1] ;
            end
        end
    end
    assign div_ctrl = stage_ctrl[`DIVIDER_STAGES] ;
    assign div_stall = |(is_stall) ;
endmodule

module Regs(
    input  logic clk, rst,
    input  logic [2:0]  i_signedchoose,
    input  logic [`REG_SIZE:0] i_dividend,
    input  logic [`REG_SIZE+1:0] i_divisor,
    input  logic [`REG_SIZE+1:0] i_remainder,
    output logic [2:0]  o_signedchoose,
    output logic [`REG_SIZE:0] o_dividend,
    output logic [`REG_SIZE+1:0] o_divisor,
    output logic [`REG_SIZE+1:0] o_remainder
);
    always_ff @(posedge clk)
    begin
        if(rst)
        begin
            o_dividend  <= 'b0 ;
            o_divisor   <= 'b0 ;
            o_remainder <= 'b0 ;
            o_signedchoose <= 'b0 ;
        end
        else begin
            o_dividend  <= i_dividend ;
            o_divisor   <= i_divisor  ;
            o_remainder <= i_remainder;
            o_signedchoose <= i_signedchoose ;
        end
    end
endmodule

module divu_1iter (
    input  logic [`REG_SIZE:0] i_dividend,
    input  logic [`REG_SIZE+1:0] i_divisor,
    input  logic [`REG_SIZE+1:0] i_remainder,
    output logic [`REG_SIZE:0] o_dividend,
    output logic [`REG_SIZE+1:0] o_remainder,
    output logic [`REG_SIZE+1:0] o_divisor
);
    logic bit_check ;
    logic [`REG_SIZE+1:0] remainder_shifted ;
    logic [`REG_SIZE:0] tmp_dividend ;

    assign o_divisor = i_divisor ;
    assign bit_check = i_remainder[`REG_SIZE+1] ;
    always_comb begin
        case(bit_check)
            1'b0: tmp_dividend = i_dividend | 'b1 ;
            1'b1: tmp_dividend = i_dividend & ~('b1) ;
            default: tmp_dividend = 'b0 ;
        endcase

        {remainder_shifted, o_dividend} = {i_remainder, tmp_dividend} << 1 ;

        case(bit_check)
            1'b0: o_remainder = remainder_shifted - i_divisor ;
            1'b1: o_remainder = remainder_shifted + i_divisor ;
            default: o_remainder = 'b0 ;
        endcase
    end
endmodule

module DividerUnsignedPipelined (
    input  logic        clk, rst,
    input  logic [2:0]  i_signedchoose,
    input  logic [`REG_SIZE:0] i_dividend,
    input  logic [`REG_SIZE:0] i_divisor,
    output logic [`REG_SIZE:0] o_remainder,
    output logic [`REG_SIZE:0] o_quotient,
    output logic [2:0]  o_signedchoose
);
    logic [`REG_SIZE:0] dividend_out_reg  [`DIVIDER_STAGES-1] ;
    logic [`REG_SIZE+1:0] divisor_out_reg   [`DIVIDER_STAGES-1] ;
    logic [`REG_SIZE+1:0] remainder_out_reg [`DIVIDER_STAGES-1] ;
    logic [`REG_SIZE:0] dividend_in_reg  [`DIVIDER_STAGES-1] ;
    logic [`REG_SIZE+1:0] divisor_in_reg   [`DIVIDER_STAGES-1] ;
    logic [`REG_SIZE+1:0] remainder_in_reg [`DIVIDER_STAGES-1] ;
    logic [2:0]  signed_choose [`DIVIDER_STAGES] ;
    assign signed_choose[0] = i_signedchoose ;

    always_comb
    begin
        // Widen 1 bit divisor and remainder to deal with overflow when calculate remainder
        dividend_in_reg[0] = i_dividend << 1 ;
        remainder_in_reg[0] = {32'b0, i_dividend[`REG_SIZE]} - {1'b0, i_divisor} ;
        divisor_in_reg[0] = {1'b0, i_divisor} ;
    end

    genvar div_unit ;
    genvar regs_unit ;
    generate;
        for(div_unit=0 ; div_unit < `DIVIDER_STAGES-2 ; div_unit++)
        begin : g_div_unit
            divu_1iter div_block(
                .i_dividend(dividend_out_reg[div_unit]),
                .i_divisor(divisor_out_reg[div_unit]),
                .i_remainder(remainder_out_reg[div_unit]),
                .o_dividend(dividend_in_reg[div_unit+1]),
                .o_remainder(remainder_in_reg[div_unit+1]),
                .o_divisor(divisor_in_reg[div_unit+1])
            );
        end

        for(regs_unit=0 ; regs_unit < `DIVIDER_STAGES-1 ; regs_unit++)
        begin : g_div_pipelined
            Regs pipelined(
                .clk(clk),
                .rst(rst),
                .i_signedchoose(signed_choose[regs_unit]),
                .i_dividend(dividend_in_reg[regs_unit]),
                .i_divisor(divisor_in_reg[regs_unit]),
                .i_remainder(remainder_in_reg[regs_unit]),
                .o_signedchoose(signed_choose[regs_unit+1]),
                .o_dividend(dividend_out_reg[regs_unit]),
                .o_divisor(divisor_out_reg[regs_unit]),
                .o_remainder(remainder_out_reg[regs_unit])
            );
        end
    endgenerate

    always_comb begin
        if(remainder_out_reg[`DIVIDER_STAGES-2][`REG_SIZE+1] == 0)
        begin
            o_quotient = dividend_out_reg[`DIVIDER_STAGES-2] |'b1;
            o_remainder = remainder_out_reg[`DIVIDER_STAGES-2][`REG_SIZE:0] ;
        end
        else begin
            o_quotient = dividend_out_reg[`DIVIDER_STAGES-2] & ~('b1);
            o_remainder= remainder_out_reg[`DIVIDER_STAGES-2][`REG_SIZE:0] +
                                                 divisor_out_reg[`DIVIDER_STAGES-2][`REG_SIZE:0];
        end

        o_signedchoose = signed_choose[`DIVIDER_STAGES-1] ;
    end
endmodule
