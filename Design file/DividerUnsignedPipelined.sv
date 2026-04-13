`timescale 1ns / 1ns

// quotient = dividend / divisor

typedef struct packed {
        logic done ;
        logic rd_we ;
        logic [4:0] rd ;
        logic [1:0] rd_in_choose ;
} div_control_t ;

module shift_register(
        input  logic clk,
        input  logic rst,
        input  logic is_div,
        input  logic invalid_decode,
        input  logic [4:0] rs1,
        input  logic [4:0] rs2,
        input  logic [4:0] rd,
        input  div_control_t cur_ctrl,
        output div_control_t delay_ctrl,
        output logic stall
);
    logic [6:0] is_stall ;
    div_control_t stage_ctrl [8] ;

    always_comb
    begin
        for(int i=0 ; i < 6 ; i++)
        begin
            is_stall[i] = ((stage_ctrl[i].done == 1) && (invalid_decode == 0) &&
                                ((rs1 == stage_ctrl[i].rd) || (rs2 == stage_ctrl[i].rd))) ;
        end
        is_stall[6] = (stage_ctrl[6].done == 1) ;
    end

    always_ff @(posedge clk)
    begin
        if(rst)
        begin
            for(int i=0 ; i < 8 ; i++)
                stage_ctrl[i] <= 9'b0 ;
        end
        else
        begin
            if(!(|is_stall) && (rd != stage_ctrl[0].rd) && (is_div))
                stage_ctrl[0] <= cur_ctrl ;
            else stage_ctrl[0] <= 9'b0 ;
            for(int i=1 ; i < 8 ; i++)
            begin
                if(rd == stage_ctrl[i-1].rd) stage_ctrl[i] <= 9'b0 ;
                else stage_ctrl[i] <= stage_ctrl[i-1] ;
            end
        end
    end
    assign delay_ctrl = stage_ctrl[7] ;

    assign stall = |(is_stall) ;
endmodule

// module Regs(
//     input  logic clk, rst,
//     input  logic [2:0]  i_signedchoose,
//     input  logic [31:0] i_dividend,
//     input  logic [31:0] i_divisor,
//     input  logic [31:0] i_remainder,
//     input  logic [31:0] i_quotient,
//     output logic [2:0]  o_signedchoose,
//     output logic [31:0] o_dividend,
//     output logic [31:0] o_divisor,
//     output logic [31:0] o_remainder,
//     output logic [31:0] o_quotient
// );
//     always_ff @(posedge clk)
//     begin
//         if(rst)
//         begin
//             o_dividend  <= 32'b0 ;
//             o_divisor   <= 32'b0 ;
//             o_remainder <= 32'b0 ;
//             o_quotient  <= 32'b0 ;
//             o_signedchoose <= 3'b0 ;
//         end
//         else begin
//             o_dividend  <= i_dividend ;
//             o_divisor   <= i_divisor  ;
//             o_remainder <= i_remainder;
//             o_quotient  <= i_quotient ;
//             o_signedchoose <= i_signedchoose ;
//         end
//     end
// endmodule

// module divu_1iter (
//     input  logic [31:0] i_dividend,
//     input  logic [31:0] i_divisor,
//     input  logic [31:0] i_remainder,
//     input  logic [31:0] i_quotient,
//     output logic [31:0] o_dividend,
//     output logic [31:0] o_remainder,
//     output logic [31:0] o_quotient
// );
//   /*
//     for (int i = 0; i < 32; i++) {
//         remainder = (remainder << 1) | ((dividend >> 31) & 0x1);
//         if (remainder < divisor) {
//             quotient = (quotient << 1);
//         } else {
//             quotient = (quotient << 1) | 0x1;
//             remainder = remainder - divisor;
//         }
//         dividend = dividend << 1;
//     }
//     */
//     logic [31:0] new_remainder ;
//     logic [32:0] sub ;
//     always_comb
//     begin
//         new_remainder = (i_remainder << 1) | (i_dividend >> 31) ;
//         sub = new_remainder - i_divisor ;
//         if(sub[32] == 0)
//         begin
//             o_remainder = sub[31:0] ;
//             o_quotient = (i_quotient << 1) |  1 ;
//         end
//         else
//         begin
//             o_remainder = new_remainder ;
//             o_quotient = i_quotient << 1 ;
//         end
//     end
//     assign o_dividend = i_dividend << 1 ;
// endmodule

// module DividerUnsignedPipelined_1_state(
//     input  logic [31:0] i_dividend,
//     input  logic [31:0] i_divisor,
//     input  logic [31:0] i_remainder,
//     input  logic [31:0] i_quotient,
//     output logic [31:0] o_dividend,
//     output logic [31:0] o_divisor,
//     output logic [31:0] o_remainder,
//     output logic [31:0] o_quotient
// );
//     logic [31:0] dividend  [4] ;
//     logic [31:0] remainder [4] ;
//     logic [31:0] quotient  [4] ;

//     genvar i ;
//     generate
//         for(i=0 ; i < 4 ; i++)
//         begin : g_1iter
//             if(i == 0)
//                 divu_1iter unit0 (
//                     .i_dividend(i_dividend),
//                     .i_divisor(i_divisor),
//                     .i_remainder(i_remainder),
//                     .i_quotient(i_quotient),
//                     .o_dividend(dividend[0]),
//                     .o_remainder(remainder[0]),
//                     .o_quotient(quotient[0])
//                 );
//             else
//                 divu_1iter unit1 (
//                     .i_dividend(dividend[i-1]),
//                     .i_divisor(i_divisor),
//                     .i_remainder(remainder[i-1]),
//                     .i_quotient(quotient[i-1]),
//                     .o_dividend(dividend[i]),
//                     .o_remainder(remainder[i]),
//                     .o_quotient(quotient[i])
//                 );
//         end
//     endgenerate

//     always_comb
//     begin
//         o_dividend = dividend[3] ;
//         o_remainder = remainder[3] ;
//         o_quotient = quotient[3] ;
//         o_divisor = i_divisor ;
//     end
// endmodule

// module DividerUnsignedPipelined (
//     input  logic        clk, rst,
//     input  logic [2:0]  i_signedchoose,
//     input  logic [31:0] i_dividend,
//     input  logic [31:0] i_divisor,
//     output logic [31:0] o_remainder,
//     output logic [31:0] o_quotient,
//     output logic [2:0]  o_signedchoose
// );

//   // TODO: your code here
//     logic [31:0] dividend_o  [8] ;
//     logic [31:0] divisor_o   [8] ;
//     logic [31:0] remainder_o [8] ;
//     logic [31:0] quotient_o  [8] ;
//     logic [31:0] dividend_i  [7] ;
//     logic [31:0] divisor_i   [7] ;
//     logic [31:0] remainder_i [7] ;
//     logic [31:0] quotient_i  [7] ;
//     logic [2:0]  signed_choose [8] ;
//     assign signed_choose[0] = i_signedchoose ;

//     genvar i ;
//     generate
//         for(i=0 ; i < 8 ; i++)
//         begin : g_div
//             if(i == 0)
//                 DividerUnsignedPipelined_1_state unit0(
//                     .i_dividend (i_dividend),
//                     .i_divisor  (i_divisor),
//                     .i_remainder(32'b0),
//                     .i_quotient (32'b0),
//                     .o_dividend (dividend_o [0]),
//                     .o_divisor  (divisor_o[0]),
//                     .o_remainder(remainder_o[0]),
//                     .o_quotient (quotient_o [0])
//                 );
//             else
//                 DividerUnsignedPipelined_1_state unit(
//                     .i_dividend (dividend_i [i-1]),
//                     .i_divisor  (divisor_i[i-1]),
//                     .i_remainder(remainder_i[i-1]),
//                     .i_quotient (quotient_i [i-1]),
//                     .o_dividend (dividend_o [i]),
//                     .o_divisor  (divisor_o [i] ),
//                     .o_remainder(remainder_o[i]),
//                     .o_quotient (quotient_o [i])
//                 );
//         end
//         // Pipelined to divided to 8 cycles
//         for(i=0 ; i < 7 ; i++)
//         begin : g_reg
//             Regs pipelining (
//                 .clk(clk),
//                 .rst(rst),
//                 .i_signedchoose(signed_choose[i]),
//                 .i_dividend (dividend_o [i]),
//                 .i_divisor  (divisor_o [i] ),
//                 .i_remainder(remainder_o[i]),
//                 .i_quotient (quotient_o [i]),
//                 .o_dividend (dividend_i [i]),
//                 .o_divisor  (divisor_i [i] ),
//                 .o_remainder(remainder_i[i]),
//                 .o_quotient (quotient_i [i]),
//                 .o_signedchoose(signed_choose[i+1])
//             );
//         end
//     endgenerate

//     always_comb
//     begin
//         o_remainder = remainder_o[7] ;
//         o_quotient  = quotient_o [7] ;
//         o_signedchoose = signed_choose[7] ;
//     end
// endmodule
