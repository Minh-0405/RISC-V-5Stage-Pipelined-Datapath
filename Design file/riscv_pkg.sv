`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31

// inst. are 32 bits in RV32IM
`define INST_SIZE 31

// RV opcodes are 7 bits
`define OPCODE_SIZE 6

package riscv_pkg;

    localparam logic [`OPCODE_SIZE:0] OpLoad    = 7'b00_000_11; // 'h03
    localparam logic [`OPCODE_SIZE:0] OpStore   = 7'b01_000_11; // 'h23

    localparam logic [`OPCODE_SIZE:0] OpBranch  = 7'b11_000_11; // 'h63
    localparam logic [`OPCODE_SIZE:0] OpJalr    = 7'b11_001_11; // 'h67
    localparam logic [`OPCODE_SIZE:0] OpJal     = 7'b11_011_11; // 'h6F
    //localparam logic [`OPCODE_SIZE:0] OpMiscMem = 7'b00_011_11; // 'h0F

    localparam logic [`OPCODE_SIZE:0] OpRegImm  = 7'b00_100_11; // 'h13
    localparam logic [`OPCODE_SIZE:0] OpRegReg  = 7'b01_100_11; // 'h33
    localparam logic [`OPCODE_SIZE:0] OpEnviron = 7'b11_100_11; // 'h73

    //localparam logic [`OPCODE_SIZE:0] OpAuipc   = 7'b00_101_11; // 'h17
    localparam logic [`OPCODE_SIZE:0] OpLui     = 7'b01_101_11; // 'h37
endpackage
