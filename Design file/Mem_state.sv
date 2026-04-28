`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31

// inst. are 32 bits in RV32IM
`define INST_SIZE 31

// RV opcodes are 7 bits
`define OPCODE_SIZE 6

`define DIVIDER_STAGES 8

module Input_Mem_control(
        input logic [`REG_SIZE:0] rs1,
        input logic [`REG_SIZE:0] imm,
        input  logic [2:0] store_control,
        input  logic [`REG_SIZE:0] input_data,
        output logic [`REG_SIZE:0] addr_to_dmem,
        output logic [`REG_SIZE:0] store_data,
        output logic [3:0] store_we,
        output logic [1:0] load_byte,
        output logic store_error
);
    assign addr_to_dmem = rs1 + imm ;
    assign load_byte = addr_to_dmem[1:0] ;


    logic [3:0] we_sb ;
    logic [3:0] we_sh ;
    logic [3:0] we_sw ;
    logic s_misalign ;
    assign s_misalign = (store_control[1] && addr_to_dmem[0])
                        || (store_control[2] && |addr_to_dmem[1:0]) ;
    always_comb begin
        we_sb = (store_control[0])? (4'b0001 << addr_to_dmem[1:0]) : 4'b0 ;
        we_sh = (store_control[1])? (4'b0011 << {addr_to_dmem[1], 1'b0}) : 4'b0 ;
        we_sw = (store_control[2])? 4'b1111 : 4'b0 ;
        store_we = {4{~(s_misalign)}} & (we_sb ^ we_sh ^ we_sw) ;
        store_error = s_misalign ;
    end

    always_comb begin
        unique case (store_control)
            3'b001: store_data = {4{input_data[7:0]}} ;
            3'b010: store_data = {2{input_data[15:0]}} ;
            3'b100: store_data = input_data ;
            default: store_data = 32'b0 ;
        endcase
    end
endmodule

module Load_value(
        input  logic [1:0] load_bytes,
        input  logic [2:0] load_control,
        input  logic [`REG_SIZE:0] load_from_dmem,
        output logic [`REG_SIZE:0] load_value,
        output logic load_error
);
    logic [7:0] b_load ;
    logic [15:0] h_load ;

    always_comb
    begin
        load_error = 1'b0 ;

        unique case (load_bytes)
            2'b00:   b_load = load_from_dmem[7:0] ;
            2'b01:   b_load = load_from_dmem[15:8] ;
            2'b10:   b_load = load_from_dmem[23:16] ;
            2'b11:   b_load = load_from_dmem[31:24] ;
            default: b_load = 8'b0 ;
        endcase

        h_load = (|load_bytes)? load_from_dmem[31:16] : load_from_dmem[15:0] ;

        unique case (load_control[1:0])
        2'b00: load_value = (load_control[2])? {24'b0, b_load}
                                      : {{24{b_load[7]}}, b_load} ;
        2'b01:  begin
            if(load_bytes[0])
            begin
                load_error = 1'b1 ;
                load_value = 32'b0 ;
            end
            else load_value = (load_control[2])? {16'b0, h_load}
                                      : {{16{h_load[15]}}, h_load};
        end
        2'b10:  begin
            if(|load_bytes)
            begin
                load_error = 1'b1 ;
                load_value = 32'b0 ;
            end
            else load_value = load_from_dmem ;
        end
        default: load_value = 32'b0 ;
      endcase
    end
endmodule

module w_pipelined(
        input  logic clk, rst,
        input  logic [`REG_SIZE:0] i_aluout,
        input  logic [`REG_SIZE:0] i_load_value,
        input  logic [`INST_SIZE:0]i_ra,
        input  logic [4:0]         i_rd,
        output logic [`REG_SIZE:0] o_aluout,
        output logic [`REG_SIZE:0] o_load_value,
        output logic [`INST_SIZE:0]o_ra,
        output logic [4:0]         o_rd
);
    always_ff @(posedge clk)
    begin
        if(rst)
        begin
            o_aluout      <= 32'b0 ;
            o_load_value  <= 32'b0 ;
            o_ra          <= 32'b0 ;
            o_rd          <= 5'b0 ;
        end
        else
        begin
            o_aluout      <= i_aluout ;
            o_load_value  <= i_load_value ;
            o_ra          <= i_ra ;
            o_rd          <= i_rd ;
        end
    end
endmodule

module w_control_pipelined(
        input  logic clk, rst,
        input  logic i_rd_we,
        input  logic [1:0] i_rd_choose,
        output logic o_rd_we,
        output logic [1:0] o_rd_choose
);
    (* max_fanout = 16 *) logic [1:0] rd_choose_reg ;
    always_ff @(posedge clk)
    begin
        if(rst)
        begin
            o_rd_we     <= 1'b0 ;
            rd_choose_reg <= 2'b0 ;
        end
        else
        begin
            o_rd_we     <= i_rd_we ;
            rd_choose_reg <= i_rd_choose ;
        end
    end
    assign o_rd_choose = rd_choose_reg ;
endmodule

