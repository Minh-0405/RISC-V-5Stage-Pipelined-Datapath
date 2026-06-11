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

    localparam logic [`OPCODE_SIZE:0] OpAuipc   = 7'b00_101_11; // 'h17
    localparam logic [`OPCODE_SIZE:0] OpLui     = 7'b01_101_11; // 'h37
endpackage

//     wire inst_lui    = (inst_opcode == OpLui    );
//     wire inst_auipc  = (inst_opcode == OpAuipc  );
//     wire inst_jal    = (inst_opcode == OpJal    );
//     wire inst_jalr   = (inst_opcode == OpJalr   );

//     wire inst_beq    = (inst_opcode == OpBranch ) & (inst_from_imem[14:12] == 3'b000);
//     wire inst_bne    = (inst_opcode == OpBranch ) & (inst_from_imem[14:12] == 3'b001);
//     wire inst_blt    = (inst_opcode == OpBranch ) & (inst_from_imem[14:12] == 3'b100);
//     wire inst_bge    = (inst_opcode == OpBranch ) & (inst_from_imem[14:12] == 3'b101);
//     wire inst_bltu   = (inst_opcode == OpBranch ) & (inst_from_imem[14:12] == 3'b110);
//     wire inst_bgeu   = (inst_opcode == OpBranch ) & (inst_from_imem[14:12] == 3'b111);

//     wire inst_lb     = (inst_opcode == OpLoad   ) & (inst_from_imem[14:12] == 3'b000);
//     wire inst_lh     = (inst_opcode == OpLoad   ) & (inst_from_imem[14:12] == 3'b001);
//     wire inst_lw     = (inst_opcode == OpLoad   ) & (inst_from_imem[14:12] == 3'b010);
//     wire inst_lbu    = (inst_opcode == OpLoad   ) & (inst_from_imem[14:12] == 3'b100);
//     wire inst_lhu    = (inst_opcode == OpLoad   ) & (inst_from_imem[14:12] == 3'b101);

//     wire inst_sb     = (inst_opcode == OpStore  ) & (inst_from_imem[14:12] == 3'b000);
//     wire inst_sh     = (inst_opcode == OpStore  ) & (inst_from_imem[14:12] == 3'b001);
//     wire inst_sw     = (inst_opcode == OpStore  ) & (inst_from_imem[14:12] == 3'b010);

//     wire inst_addi   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b000);
//     wire inst_slti   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b010);
//     wire inst_sltiu  = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b011);
//     wire inst_xori   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b100);
//     wire inst_ori    = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b110);
//     wire inst_andi   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b111);

//     wire inst_slli   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b001) & (inst_from_imem[31:25] == 7'd0      );
//     wire inst_srli   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b101) & (inst_from_imem[31:25] == 7'd0      );
//     wire inst_srai   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b101) & (inst_from_imem[31:25] == 7'b0100000);

//     wire inst_add    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b000) & (inst_from_imem[31:25] == 7'd0      );
//     wire inst_sub    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b000) & (inst_from_imem[31:25] == 7'b0100000);
//     wire inst_sll    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b001) & (inst_from_imem[31:25] == 7'd0      );
//     wire inst_slt    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b010) & (inst_from_imem[31:25] == 7'd0      );
//     wire inst_sltu   = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b011) & (inst_from_imem[31:25] == 7'd0      );
//     wire inst_xor    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b100) & (inst_from_imem[31:25] == 7'd0      );
//     wire inst_srl    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b101) & (inst_from_imem[31:25] == 7'd0      );
//     wire inst_sra    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b101) & (inst_from_imem[31:25] == 7'b0100000);
//     wire inst_or     = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b110) & (inst_from_imem[31:25] == 7'd0      );
//     wire inst_and    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b111) & (inst_from_imem[31:25] == 7'd0      );

//     wire inst_mul    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b000) & (inst_from_imem[31:25] == 7'd1  ) ;
//     wire inst_mulh   = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b001) & (inst_from_imem[31:25] == 7'd1  ) ;
//     wire inst_mulhsu = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b010) & (inst_from_imem[31:25] == 7'd1  ) ;
//     wire inst_mulhu  = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b011) & (inst_from_imem[31:25] == 7'd1  ) ;
//     wire inst_div    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b100) & (inst_from_imem[31:25] == 7'd1  ) ;
//     wire inst_divu   = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b101) & (inst_from_imem[31:25] == 7'd1  ) ;
//     wire inst_rem    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b110) & (inst_from_imem[31:25] == 7'd1  ) ;
//     wire inst_remu   = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b111) & (inst_from_imem[31:25] == 7'd1  ) ;

//     wire inst_ecall  = (inst_opcode == OpEnviron) & (inst_from_imem[31:7] == 25'd0  );
//     wire inst_fence  = (inst_opcode == OpMiscMem);
