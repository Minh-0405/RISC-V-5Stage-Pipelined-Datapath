`timescale 1ns / 1ns

module riscv_test_tb() ;
    logic clk ;
    logic rst ;
    logic halt ;

    Processor dut (
        .clk(clk),
        .rst(rst),
        .halt(halt)
    );

    task automatic clock(input int number); //Creat proc_clock and mem_clock
        repeat (number) begin
            clk = 1'b1 ; #1 ;
            clk = 1'b0 ; #1 ;
        end
    endtask

    task automatic expect_rf(input int value, input int index);
        if(dut.datapath.rf.regs[index] === value)
            $display("TEST PASS") ;
        else
            $error ("TEST FAILED: expected %0h, got %0h", value, dut.datapath.rf.regs[index]) ;
    endtask

    task automatic run_test(input string hex_file, input int num);
        for(int i=0 ; i<$size(dut.memory.mem_array) ; i++) dut.memory.mem_array[i] = 'b0 ;
        for(int i=0 ; i<$size(dut.DMEM.mem_array) ; i++) dut.DMEM.mem_array[i] = 'b0 ;
        $readmemh(hex_file, dut.memory.mem_array) ;
        $readmemh(hex_file, dut.DMEM.mem_array) ;
        //Load data section into DMEM for load test, the reduntant instruction load to DMEM don't affect the test

        rst = 1'b1 ; clock(2) ; rst = 1'b0 ;
        for(int i=0 ; i<num & !dut.datapath.halt ; i++)
        begin
            clock(1) ;
        end
        clock(3) ;

        expect_rf(32'h1, 3) ;
    endtask

    initial
    begin
        $display("\n============TESTCASE: SIMPLE TEST============\n");
        run_test("simple_test.hex", 700) ;

        $display("\n============TESTCASE: ADD============\n");
        run_test("add_test.hex", 700) ;
        run_test("addi_test.hex", 700) ;

        $display("\n============TESTCASE: SUB============\n");
        run_test("sub_test.hex", 700) ;

        $display("\n============TESTCASE: AND============\n");
        run_test("and_test.hex", 700) ;
        run_test("andi_test.hex", 700) ;

        $display("\n============TESTCASE: OR============\n");
        run_test("or_test.hex", 700) ;
        run_test("ori_test.hex", 700) ;

        $display("\n============TESTCASE: XOR============\n");
        run_test("xor_test.hex", 700) ;
        run_test("xori_test.hex", 700) ;

        $display("\n============TESTCASE: SLT============\n");
        run_test("slt_test.hex", 700) ;
        run_test("sltu_test.hex", 700) ;
        run_test("slti_test.hex", 700) ;
        run_test("sltiu_test.hex", 700) ;

        $display("\n============TESTCASE: SLL============\n");
        run_test("sll_test.hex", 700) ;
        run_test("slli_test.hex", 700) ;

        $display("\n============TESTCASE: SRL============\n");
        run_test("srl_test.hex", 700) ;
        run_test("srli_test.hex", 700) ;

        $display("\n============TESTCASE: SRA============\n");
        run_test("sra_test.hex", 700) ;
        run_test("srai_test.hex", 700) ;

        $display("\n============TESTCASE: LUI============\n");
        run_test("lui_test.hex", 700) ;

        $display("\n============TESTCASE: AUIPC============\n");
        run_test("auipc_test.hex", 700) ;

        $display("\n============TESTCASE: BEQ============\n");
        run_test("beq_test.hex", 700) ;

        $display("\n============TESTCASE: BNE============\n");
        run_test("bne_test.hex", 700) ;

        $display("\n============TESTCASE: BLT============\n");
        run_test("blt_test.hex", 700) ;
        run_test("bltu_test.hex", 700) ;

        $display("\n============TESTCASE: BGE============\n");
        run_test("bge_test.hex", 700) ;
        run_test("bgeu_test.hex", 700) ;

        $display("\n============TESTCASE: JUMP============\n");
        run_test("jal_test.hex", 700) ;
        run_test("jalr_test.hex", 700) ;

        $display("\n============TESTCASE: LB============\n");
        run_test("lb_test.hex", 1000) ;
        run_test("lbu_test.hex", 1000) ;

        $display("\n============TESTCASE: LH============\n");
        run_test("lh_test.hex", 1000) ;
        run_test("lhu_test.hex", 1000) ;

        $display("\n============TESTCASE: LW============\n");
        run_test("lw_test.hex", 1000) ;

        $display("\n============TESTCASE: SB============\n");
        run_test("sb_test.hex", 1000) ;

        $display("\n============TESTCASE: SH============\n");
        run_test("sh_test.hex", 1000) ;

        $display("\n============TESTCASE: SW============\n");
        run_test("sw_test.hex", 1000) ;

        $display("\n============TESTCASE: LOAD-STORE============\n");
        run_test("ld_st_test.hex", 1500) ;
        run_test("st_ld_test.hex", 1500) ;

        $display("\n============TESTCASE: DIV============\n");
        run_test("div_test.hex", 1500) ;
        run_test("divu_test.hex", 1500) ;

        $display("\n============TESTCASE: REM============\n");
        run_test("rem_test.hex", 1500) ;
        run_test("remu_test.hex", 1500) ;

        $display("\n============TESTCASE: MUL============\n");
        run_test("mul_test.hex", 1500) ;
        run_test("mulh_test.hex", 1500) ;
        run_test("mulhsu_test.hex", 1500) ;
        run_test("mulhu_test.hex", 1500) ;
    end

endmodule
