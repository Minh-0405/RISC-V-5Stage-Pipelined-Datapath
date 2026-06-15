`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31

// inst. are 32 bits in RV32IM
`define INST_SIZE 31

// RV opcodes are 7 bits
`define OPCODE_SIZE 6


//`include "Decode_state.sv"
//`include "Execute_state.sv"
//`include "Mem_state.sv"
//`include "Hazard_resolution.sv"
//`include "Branch_unit.sv"


module f_pipelined (
        input  logic clk, rst,
        input  logic freeze,
        input  logic [`REG_SIZE:0] i_inst,
        input  logic [`REG_SIZE:0] i_pc,
        output logic [`REG_SIZE:0] o_pc,
        output logic [`REG_SIZE:0] o_inst
);
    always_ff @(posedge clk)
    begin
        if(rst)
        begin
            o_pc <= 32'b0 ;
            o_inst <= 32'b0 ;
        end
        else if(!freeze)
        begin
            o_pc <= i_pc ;
            o_inst <= i_inst ;
        end
    end
endmodule

module DatapathPipelined
    import riscv_pkg::* ;
(
        input  logic                clk,
        input  logic                rst,
        output logic [ `REG_SIZE:0] pc_to_imem,
        input  logic [`INST_SIZE:0] inst_from_imem,
        // dmem is read/write
        output logic [ `REG_SIZE:0] addr_to_dmem,
        input  logic [ `REG_SIZE:0] load_data_from_dmem,
        output logic [ `REG_SIZE:0] store_data_to_dmem,
        output logic [         3:0] store_we_to_dmem,
        output logic                halt,
        output logic                error
);

    //cycle counter, not really part of any stage but useful for orienting within waveform
    //only use for simulation, synthesize will ignore it
    logic [`REG_SIZE:0] cycles_current;
    always_ff @(posedge clk) begin
      if (rst) begin
          cycles_current <= 0;
      end else begin
          cycles_current <= cycles_current  + 1;
      end
    end

    logic [3:0] e ;
    assign error = !e ;
    // e[0] = address overflow ; e[1] = load_misaligned ; e[2] = store_misaligned
    // e[3] = illegal_inst

    /*******************/
    /* PREPARE SIGNALS */
    /*******************/
    logic load_stall ;
    logic rd_we_fromW ;
    logic rd_we_fromM ;
    logic [4:0] rd_fromX ;
    logic [4:0] rd_fromM ;
    logic [4:0] rd_fromW ;
    logic [1:0] rd_choose_fromM ;
    logic [`REG_SIZE:0] aluout_fromM ;
    logic [`REG_SIZE:0] f_next_pc;
    logic [`REG_SIZE:0] pc_branch ;
    logic [`REG_SIZE:0] pc_branch_fromM ;
    logic is_branch ;
    logic [`INST_SIZE:0] inst_fromD ;
    logic [`REG_SIZE:0]  pc_fromD ;
    logic [6:0] inst_funct7 ;
    logic [2:0] inst_funct3 ;
    logic [4:0] inst_rd ;
    logic [4:0] inst_rs1;
    logic [4:0] inst_rs2;
    logic [`OPCODE_SIZE:0] inst_opcode ;
    logic [`REG_SIZE:0] rs1_data, rs2_data ;
    logic [`REG_SIZE:0] rd_in ;
    logic [`REG_SIZE:0] imm_operand ;
    logic [2:0] store_control ;
    logic [2:0] load_control ;
    logic [1:0] rd_choose ;
    logic op2_choose ;
    logic op1_choose ;
    logic is_lui ;
    logic rd_we ;
    logic [3:0] branch_control ;
    logic [1:0] jump ;
    logic is_load ;
    logic [1:0] rd_choose_fromX ;
    logic [`REG_SIZE:0] pc_fromX ;
    logic [`REG_SIZE:0] rs1_fromX ;
    logic [`REG_SIZE:0] rs2_fromX ;
    logic [`REG_SIZE:0] imm_fromX ;
    logic [2:0] store_control_fromX ;
    logic [2:0] load_control_fromX ;
    logic [3:0] alu_control_fromX ;
    logic [4:0] rs1_addr ;
    logic [4:0] rs2_addr ;
    logic op2_choose_fromX ;
    logic op1_choose_fromX ;
    logic is_div_mul_fromX ;
    logic is_lui_fromX ;
    logic rd_we_fromX ;
    logic [3:0] branch_fromX ;
    logic [1:0] jump_fromX ;
    logic [`REG_SIZE:0] tmp_pc ;
    logic [`REG_SIZE:0] base_addr ;
    logic [`REG_SIZE:0] return_addr ;
    logic [2:0] alu_operation ;
    logic is_sub, is_sra, b_type ;
    logic [`REG_SIZE:0] operand1 ;
    logic [`REG_SIZE:0] operand2 ;
    logic [`REG_SIZE:0] base_op2 ;
    logic [`REG_SIZE:0] base_op1 ;
    logic [1:0] op1_control ;
    logic [1:0] op2_control ;
    logic [`REG_SIZE:0] alu_out ;
    logic [`REG_SIZE:0] quotient ;
    logic [`REG_SIZE:0] remainder ;
    logic [(`REG_SIZE)*2+1:0] mul_out ;
    logic [2:0] m_aluout_choose ;
    logic [`REG_SIZE:0] quotient_fromM ;
    logic [`REG_SIZE:0] remainder_fromM ;
    logic [(`REG_SIZE)*2+1:0] mul_out_fromM ;
    logic [2:0] m_aluout_choose_fromM ;
    logic [`REG_SIZE:0] neg_quotient ;
    logic [`REG_SIZE:0] neg_remainder ;
    logic [`REG_SIZE:0] m_alu_out ;
    logic [`REG_SIZE:0] final_ex_data ;
    logic [`REG_SIZE:0] ex_data ;
    logic [`REG_SIZE:0] lui_data_fromM ;
    logic is_lui_fromM ;
    logic is_div_mul ;
    logic div_mul ;
    logic div_mul_fromM ;
    logic is_div ;
    logic is_mul ;
    logic div_stall ;
    logic mul_stall ;
    logic b_cond ;
    logic b_cond_fromM ;
    logic jump_fromM ;
    logic branch_fromM ;
    logic s_bypass_ex ;
    logic [1:0] load_byte ;
    logic [1:0] load_byte_fromM ;
    logic [`REG_SIZE:0] s_data_ex ;
    logic [`INST_SIZE:0] ra_fromM ;
    logic [`REG_SIZE:0] rs2_data_fromM ;
    logic [4:0] rs2_addr_fromM ;
    logic [2:0] load_control_fromM ;
    logic [`REG_SIZE:0] load_value ;
    logic s_bypass_mem ;
    logic [`REG_SIZE:0] s_data ;
    logic [`REG_SIZE:0] aluout_fromW ;
    logic [`REG_SIZE:0] load_value_fromW ;
    logic [`INST_SIZE:0] ra_fromW ;
    logic rd_choose_fromW ;
    logic rd_we_inM ;
    logic [1:0]rd_in_choose_inM ;
    logic [4:0] rd_inM ;
    logic [`REG_SIZE:0] forward_data ;
    logic [4:0] w_forward_rd ;
    logic choose_mul_ctrl ;
    logic invalid_decode ;
    div_control_t ctrl ;
    div_control_t div_ctrl ;
    div_control_t mul_ctrl ;
    /***************/
    /* FETCH STAGE */
    /***************/
    // program counter
    always_ff @(posedge clk) begin
      if (rst)
      begin
        f_next_pc <= 32'd0;
      end
      else if(!(load_stall | div_stall | mul_stall | halt)) f_next_pc <= pc_to_imem + 4 ;
    end
    // send PC to imem
    assign pc_to_imem = (is_branch)? pc_branch_fromM : f_next_pc;

    // branch signal on will break the stall of this pipelined
    f_pipelined D (
        .clk(clk),
        .rst(rst),
        .freeze((!is_branch) && ((load_stall) || (div_stall) || (mul_stall) || (halt))),
        .i_pc(pc_to_imem),
        .i_inst(inst_from_imem),
        .o_pc(pc_fromD),
        .o_inst(inst_fromD)
    );

    /****************/
    /* DECODE STAGE */
    /****************/
    assign {inst_funct7, inst_rs2, inst_rs1, inst_funct3, inst_rd, inst_opcode} = inst_fromD ;
    RegFile rf(
        .clk(clk),
        .we(rd_we_fromW),
        .rd(rd_fromW),
        .rd_data(rd_in),
        .rs1(inst_rs1),
        .rs1_data(rs1_data),
        .rs2(inst_rs2),
        .rs2_data(rs2_data)
    );

    Imm_Gen ImmGen (
        .inst(inst_fromD),
        .imm(imm_operand)
    );

    Control_unit CU (
      .inst(inst_fromD),
      .store_control(store_control),
      .load_control(load_control),
      .is_div_mul(is_div_mul),
      .is_lui(is_lui),
      .rd_in_choose(rd_choose),
      .rd_we(rd_we),
      .alu_operand2(op2_choose),
      .alu_operand1(op1_choose),
      .branch(branch_control),
      .jump(jump),
      .invalid_decode(invalid_decode),
      .halt(halt)
    );
    assign e[3] = invalid_decode ; //illegal_inst

    assign is_load = (rd_choose_fromX == 2'b01) ;
    load_stall detect_load_stall(
      .is_load(is_load),
      .rs1(inst_rs1),
      .rs2(inst_rs2),
      .ex_rd(rd_fromX),
      .stall(load_stall)
    );

    mul_stall detect_mul_stall(
      .mul_setup(is_mul),
      .mul_ex(choose_mul_ctrl),
      .rs1(inst_rs1),
      .rs2(inst_rs2),
      .ex_rd(rd_inM),
      .stall(mul_stall)
    );

    assign ctrl = {(is_div_mul & inst_funct3[2] == 1'b1), rd_we, inst_rd, rd_choose} ;
    shift_register Shift_divcontrol(
      .clk(clk),
      .rst(rst),
      .invalid_decode(invalid_decode),
      .rs1(inst_rs1),
      .rs2(inst_rs2),
      .rd(inst_rd),
      .cur_ctrl(ctrl),
      .div_ctrl(div_ctrl),
      .div_stall(div_stall)
    );

    x_pipelined X(
      .clk(clk), .rst(rst),
      .i_rs1_data(rs1_data),
      .i_rs2_data(rs2_data),
      .i_imm_data(imm_operand),
      .i_rd(inst_rd),
      .i_rs1(inst_rs1),
      .i_rs2(inst_rs2),
      .i_pc(pc_fromD),
      .o_rs1_data(rs1_fromX),
      .o_rs2_data(rs2_fromX),
      .o_imm_data(imm_fromX),
      .o_rd(rd_fromX),
      .o_rs1(rs1_addr),
      .o_rs2(rs2_addr),
      .o_pc(pc_fromX)
    );

    x_control_pipelined Xcontrol(
      .clk(clk), .rst(rst),
      .nops((is_branch || load_stall || div_stall || mul_stall || halt)),
      .i_store_control(store_control),
      .i_load_control(load_control),
      .i_is_div_mul(is_div_mul),
      .i_is_lui(is_lui),
      .i_rd_we(rd_we),
      .i_rd_in_choose(rd_choose),
      .i_alu_operand2(op2_choose),
      .i_alu_operand1(op1_choose),
      .i_alu_control({inst_fromD[30],inst_funct3}),
      .i_inst_branch(branch_control),
      .i_inst_jump(jump),
      .o_store_control(store_control_fromX),
      .o_load_control(load_control_fromX),
      .o_is_div_mul(is_div_mul_fromX),
      .o_is_lui(is_lui_fromX),
      .o_rd_we(rd_we_fromX),
      .o_rd_in_choose(rd_choose_fromX),
      .o_alu_operand2(op2_choose_fromX),
      .o_alu_operand1(op1_choose_fromX),
      .o_alu_control(alu_control_fromX),
      .o_inst_branch(branch_fromX),
      .o_inst_jump(jump_fromX)
    );

    /*****************/
    /* EXECUTE STAGE */
    /*****************/

    detect_ExForwarding bypassing_ex (
      .we({rd_we_fromW, rd_we_fromM}),
      .rs1(rs1_addr),
      .rs2(rs2_addr),
      .m_rd(rd_fromM),
      .w_rd(w_forward_rd),
      .op1_control(op1_control),
      .op2_control(op2_control)
    ) ;

    choice_operand op1(
      .op_control(op1_control),
      .rs(rs1_fromX),
      .mem_forward(ex_data),
      .wb_forward(forward_data),
      .operand(base_op1)
    );
    assign operand1 = (op1_choose_fromX)? pc_fromX : base_op1 ;

    choice_operand op2(
      .op_control(op2_control),
      .rs(rs2_fromX),
      .mem_forward(ex_data),
      .wb_forward(forward_data),
      .operand(base_op2)
    );
    assign operand2 = (op2_choose_fromX)? imm_fromX : base_op2 ;

    // base_addr is pc for branch and jal /  rs1 for jalr
    assign base_addr = (jump_fromX[1])? operand1 : pc_fromX ;
    cla Br_Adress (
        .a(base_addr),
        .b(imm_fromX),
        .sum(tmp_pc),
        .cin(1'b0),
        .carry_out(e[0])
    );
    //set the last bit to 0 for JALR, remain branch already have the last bit is 0
    assign pc_branch = {tmp_pc[31:1], 1'b0} ;
    assign return_addr = pc_fromX + 4 ;

    Branch_condition Br_Unit(
        .branch_control(branch_fromX[3:1]),
        .rs1(operand1),
        .rs2(operand2),
        .b_cond(b_cond)
    );

    ALUs ALU(
      .inst_type(op2_choose_fromX),
      .auipc(op1_choose_fromX),
      .rs1(operand1),
      .rs2(operand2),
      .control(alu_control_fromX),
      .alu_out(alu_out)
    );

    M_ALUs M_ALU(
      .clk(clk),
      .rst(rst),
      .rs1(operand1),
      .rs2(operand2),
      .control(alu_control_fromX[2:0]),
      .div_done(div_ctrl.done),
      .quot_out(quotient),
      .rem_out(remainder),
      .mul_out(mul_out),
      .m_alu_choose(m_aluout_choose)
    );

    assign is_div = (is_div_mul_fromX && alu_control_fromX[2] == 1'b1) ;

    // Always stall 1 clk for mul execute because of setup stage for mul
    // Also a signal to detect it is mul inst (is_mul)
    assign is_mul = (is_div_mul_fromX && alu_control_fromX[2] == 1'b0) ;
    always_ff @(posedge clk)
    begin
      choose_mul_ctrl <= is_mul ;
      mul_ctrl <= {1'b0, rd_we_fromX, rd_fromX, rd_choose_fromX} ;
    end
    always_comb begin
      rd_inM = choose_mul_ctrl? mul_ctrl.rd : rd_fromX ;
      rd_we_inM = choose_mul_ctrl? mul_ctrl.rd_we : rd_we_fromX ;
      rd_in_choose_inM = choose_mul_ctrl? mul_ctrl.rd_in_choose : rd_choose_fromX ;

      div_mul = (div_ctrl.done | choose_mul_ctrl)? 1'b1 : 1'b0 ;
    end

    Input_Mem_control Input_Dmem(
      .rs1(operand1),
      .imm(imm_fromX),
      .store_control(store_control_fromX),
      .input_data(operand2),
      .addr_to_dmem(addr_to_dmem),
      .store_data(store_data_to_dmem),
      .store_we(store_we_to_dmem),
      .load_byte(load_byte),
      .store_error(e[2])
    );

    m_pipelined M(
      .clk(clk), .rst(rst),
      .i_pc_branch(pc_branch),
      .i_aluout(alu_out),
      .i_quotient(quotient),
      .i_remainder(remainder),
      .i_mulout(mul_out),
      .i_m_aluout_choose(m_aluout_choose),
      .i_load_byte(load_byte),
      .i_lui_data(imm_fromX),
      .i_rs2_addr(rs2_addr),
      .i_ra(return_addr),
      .o_pc_branch(pc_branch_fromM),
      .o_aluout(aluout_fromM),
      .o_quotient(quotient_fromM),
      .o_remainder(remainder_fromM),
      .o_mulout(mul_out_fromM),
      .o_m_aluout_choose(m_aluout_choose_fromM),
      .o_load_byte(load_byte_fromM),
      .o_lui_data(lui_data_fromM),
      .o_rs2_addr(rs2_addr_fromM),
      .o_ra(ra_fromM)
    );

    m_control_pipelined Mcontrol(
      .clk(clk), .rst(rst),
      .nops(is_branch | is_mul | is_div | div_ctrl.done),
      .i_is_lui(is_lui_fromX),
      .i_b_cond(b_cond),
      .i_jump(jump_fromX[0]),
      .i_branch(branch_fromX[0]),
      .i_load_control(load_control_fromX),
      .o_is_lui(is_lui_fromM),
      .o_b_cond(b_cond_fromM),
      .o_jump(jump_fromM),
      .o_branch(branch_fromM),
      .o_load_control(load_control_fromM)
    );

    m_div_mul_control_pipelined M_div_mul(
      .clk(clk), .rst(rst),
      .nops(is_branch | is_mul | is_div),
      .div_ctrl(div_ctrl),
      .i_rd_we(rd_we_inM),
      .i_rd(rd_inM),
      .i_rd_in_choose(rd_in_choose_inM),
      .i_div_mul(div_mul),
      .o_rd_we(rd_we_fromM),
      .o_rd(rd_fromM),
      .o_rd_in_choose(rd_choose_fromM),
      .o_div_mul(div_mul_fromM)
    );

    /****************/
    /* MEMORY STAGE */
    /****************/

    always_comb
    begin
      case({rd_choose_fromM[1], is_lui_fromM})
        2'b00:  ex_data = aluout_fromM ;
        2'b01:  ex_data = lui_data_fromM ;
        2'b10, 2'b11:  ex_data = ra_fromM ;
        default:  ex_data = ra_fromM ;
      endcase
    end

    transform_2_compliment neg_quot(
      .in(quotient_fromM),
      .out(neg_quotient)
    );
    transform_2_compliment neg_rem(
      .in(remainder_fromM),
      .out(neg_remainder)
    );

    always_comb
    begin
      case (m_aluout_choose_fromM)
        3'b000: m_alu_out = mul_out_fromM[31:0] ;
        3'b001: m_alu_out = mul_out_fromM[63:32] ;
        3'b100: m_alu_out = quotient_fromM ;
        3'b101: m_alu_out = neg_quotient ;
        3'b110: m_alu_out = remainder_fromM ;
        3'b111: m_alu_out = neg_remainder ;
        default: m_alu_out = 32'b0 ;
      endcase
    end

    assign final_ex_data = div_mul_fromM? m_alu_out : ex_data ;

    Detect_branch detect_branch(
      .b_cond(b_cond_fromM),
      .inst_jump(jump_fromM),
      .inst_branch(branch_fromM),
      .is_branch(is_branch)
    );

    Load_value modify_load_value(
      .load_bytes(load_byte_fromM),
      .load_control(load_control_fromM),
      .load_from_dmem(load_data_from_dmem),
      .load_value(load_value),
      .load_error(e[1])
    );

    wb_forward_pipelined wb_forward(
      .clk(clk),
      .rst(rst),
      .aluout(final_ex_data),
      .load_value(load_value),
      .rd(rd_fromM),
      .rd_choose(rd_choose_fromM[0]),
      .forward_data(forward_data),
      .w_forward_rd(w_forward_rd)
    );

    w_pipelined W(
      .clk(clk), .rst(rst),
      .i_aluout(final_ex_data),
      .i_load_value(load_value),
      .i_rd(rd_fromM),
      .o_aluout(aluout_fromW),
      .o_load_value(load_value_fromW),
      .o_rd(rd_fromW)
    );

    w_control_pipelined Wcontrol(
      .clk(clk), .rst(rst),
      .i_rd_we(rd_we_fromM & (~e[1])), // Stop load value when misalign addr error
      .i_rd_choose(rd_choose_fromM[0]),
      .o_rd_we(rd_we_fromW),
      .o_rd_choose(rd_choose_fromW)
    );

    /*******************/
    /* WRITEBACK STAGE */
    /*******************/
    always_comb
    begin
      unique case(rd_choose_fromW)
        1'b0:   rd_in = aluout_fromW ;
        1'b1:   rd_in = load_value_fromW ;
        default: rd_in = aluout_fromW ;
      endcase
    end

endmodule

module DataMemory #(
    parameter int NUM_WORDS = 512
) (
    input  logic               rst,                 // rst for both imem and dmem
    input  logic               clk,                 // clock for both imem and dmem
                                                    // The memory reads/writes on @(negedge clk)
    input  logic [`REG_SIZE:0] addr_to_dmem,        // must always be aligned to a 4B boundary
    output logic [`REG_SIZE:0] load_data_from_dmem, // the value at memory location addr_to_dmem
    input  logic [`REG_SIZE:0] store_data_to_dmem,  // the value to be written to addr_to_dmem
    // Each bit determines whether to write the corresponding byte of store_data_to_dmem to memory location addr_to_dmem.
    // E.g., 4'b1111 will write 4 bytes. 4'b0001 will write only the least-significant byte.
    input  logic [        3:0] store_we_to_dmem
);
  // memory is arranged as an array of 4B words
  // riscv_test in github design for 2bytes memory cell
  // remember to define RISCV_TEST when run riscv_test
  localparam int AddrMsb = $clog2(NUM_WORDS) + 1;
  localparam int AddrLsb = 2;
  `ifndef RISCV_TEST
    // Normal mode
    logic [`REG_SIZE:0] mem_array [NUM_WORDS];
  `else
    // Riscv_test mode
    logic [7:0] mem_array [NUM_WORDS*4] ;
    wire [`REG_SIZE:0] addr_aligned = addr_to_dmem[AddrMsb:AddrLsb] << 2 ;
  `endif

  always_ff @(posedge clk) begin
    `ifndef RISCV_TEST
      // Normal mode
      if(!rst)
      begin
        if (store_we_to_dmem[0]) begin
          mem_array[addr_to_dmem[AddrMsb:AddrLsb]][7:0] <= store_data_to_dmem[7:0];
        end
        if (store_we_to_dmem[1]) begin
          mem_array[addr_to_dmem[AddrMsb:AddrLsb]][15:8] <= store_data_to_dmem[15:8];
        end
        if (store_we_to_dmem[2]) begin
          mem_array[addr_to_dmem[AddrMsb:AddrLsb]][23:16] <= store_data_to_dmem[23:16];
        end
        if (store_we_to_dmem[3]) begin
          mem_array[addr_to_dmem[AddrMsb:AddrLsb]][31:24] <= store_data_to_dmem[31:24];
        end
        load_data_from_dmem <= mem_array[addr_to_dmem[AddrMsb:AddrLsb]];
      end
    `else
      // Riscv_test mode
      if(!rst)
      begin
        if (store_we_to_dmem[0]) begin
          mem_array[addr_aligned] <= store_data_to_dmem[7:0];
        end
        if (store_we_to_dmem[1]) begin
          mem_array[addr_aligned+1] <= store_data_to_dmem[15:8];
        end
        if (store_we_to_dmem[2]) begin
          mem_array[addr_aligned+2] <= store_data_to_dmem[23:16];
        end
        if (store_we_to_dmem[3]) begin
          mem_array[addr_aligned+3] <= store_data_to_dmem[31:24];
        end
        load_data_from_dmem <= {mem_array[addr_aligned+3],
                        mem_array[addr_aligned+2],
                        mem_array[addr_aligned+1],
                        mem_array[addr_aligned]} ;
      end
    `endif
  end
endmodule

module InstMemory #(
    parameter int NUM_WORDS = 512
) (
    input  logic               clk,                 // clock for both imem and dmem
                                                    // The memory reads/writes on @(negedge clk)
    input  logic [`REG_SIZE:0] pc_to_imem,          // must always be aligned to a 4B boundary
    output logic [`REG_SIZE:0] inst_from_imem       // the value at memory location pc_to_imem
);
  // memory is arranged as an array of 4B words
  // riscv_test in github design for 2bytes memory cell

  `ifndef RISCV_TEST
    // Normal mode
    logic [`REG_SIZE:0] mem_array [NUM_WORDS];
    localparam int AddrMsb = $clog2(NUM_WORDS) + 1;
    localparam int AddrLsb = 2;
  `else
    // Riscv_test mode
    logic [7:0] mem_array [NUM_WORDS*4] ;
    localparam int AddrMsb = $clog2(NUM_WORDS) + 1;
    localparam int AddrLsb = 0;
  `endif

  //preload instructions to mem_array for implement
  //erase it when simulate cause testbench will load instructions into memory
  initial begin
    $readmemh("mem_initial_contents.hex", mem_array);
  end

  always_ff @(negedge clk) begin
    `ifndef RISCV_TEST
      // Normal mode
      inst_from_imem <= mem_array[pc_to_imem[AddrMsb:AddrLsb]];
    `else
      // Riscv_test mode
      inst_from_imem <= {mem_array[pc_to_imem[AddrMsb:AddrLsb]+3],
                        mem_array[pc_to_imem[AddrMsb:AddrLsb]+2],
                        mem_array[pc_to_imem[AddrMsb:AddrLsb]+1],
                        mem_array[pc_to_imem[AddrMsb:AddrLsb]]} ;
    `endif
  end
endmodule

/* This design has just one clock for both processor and memory. */
module Processor (
    input                 clk,
    input                 rst,
    output                halt,
    output                error
);

  (* max_fanout = 16 *) logic rst_syn ;
  always_ff @(posedge clk)
  begin
    rst_syn <= rst ;
  end

  logic [`INST_SIZE:0] inst_from_imem;
  logic [ `REG_SIZE:0] pc_to_imem, mem_data_addr, mem_data_loaded_value ;
  logic [`REG_SIZE:0] mem_data_to_write ;
  logic [         3:0] mem_data_we;

  // This wire is set by cocotb to the name of the currently-running test, to make it easier
  // to see what is going on in the waveforms.
  logic [(8*32)-1:0] test_case;

  InstMemory #(
      .NUM_WORDS(8192)
  ) memory (
    .clk                 (clk),
    // imem is read-only
    .pc_to_imem          (pc_to_imem),
    .inst_from_imem      (inst_from_imem)
  );

  DataMemory #(
      .NUM_WORDS(8192)
  ) DMEM (
    .rst                 (rst_syn),
    .clk                 (clk),
    // dmem is read-write
    .addr_to_dmem        (mem_data_addr),
    .load_data_from_dmem (mem_data_loaded_value),
    .store_data_to_dmem  (mem_data_to_write),
    .store_we_to_dmem    (mem_data_we)
  );

  DatapathPipelined datapath (
    .clk                  (clk),
    .rst                  (rst_syn),
    .pc_to_imem           (pc_to_imem),
    .inst_from_imem       (inst_from_imem),
    .addr_to_dmem         (mem_data_addr),
    .store_data_to_dmem   (mem_data_to_write),
    .store_we_to_dmem     (mem_data_we),
    .load_data_from_dmem  (mem_data_loaded_value),
    .halt                 (halt),
    .error                (error)
  );

endmodule
