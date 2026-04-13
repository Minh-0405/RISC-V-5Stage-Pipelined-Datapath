`timescale 1ns / 1ns
`define REG_SIZE 31
`define INST_SIZE 31


module DatapathPipelined_tb() ;
    logic clk ;
    logic rst ;
    logic halt ;
    logic [ `REG_SIZE:0] trace_writeback_pc ;
    logic [`INST_SIZE:0] trace_writeback_inst ;

    Processor dut (
        .clk(clk),
        .rst(rst),
        .halt(halt),
        .trace_writeback_pc(trace_writeback_pc),
        .trace_writeback_inst(trace_writeback_inst)
    );
    // preload instructions to mem_array
    // initial begin
    //     $readmemh("mem_initial_contents.hex", mem_array);
    // end

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

    task automatic expect_halt() ;
        if(dut.datapath.halt == 1)
            $display("TEST PASS: The processor halt correctly") ;
        else $error ("FAILED: The process not halt") ;
    endtask

    task automatic clear_imem(input int number);
        for(int i=0 ; i < number ; i++)
        begin
            dut.memory.mem_array[i] = 0 ;
        end
    endtask

    task automatic test_individual ();
        dut.memory.mem_array[0] = 32'h8980;

    endtask

    initial begin
         $display("\n============TESTCASE: ALU INSTRUCTION============\n");
         // lui x1, 0x12345     -> x1 = 0x12345000
         dut.memory.mem_array[0]  = 32'h123450b7;
         // addi x1, x1, 0x123  -> x1 = 0x12345123
         dut.memory.mem_array[1]  = 32'h12308093;
         // slli x2, x1, 4      -> x2 = 0x23451230 (Shift Left logical)
         dut.memory.mem_array[2]  = 32'h00409113;
         // srli x3, x2, 8      -> x3 = 0x00234512 (Shift Right Logical)
         dut.memory.mem_array[3]  = 32'h00815193;

         // ALU
         // add x4, x3, x1      -> x4 = 0x12579635 (0x00234512 + 0x12345123)
         dut.memory.mem_array[4]  = 32'h00118233;
         // sub x5, x1, x3      -> x5 = 0x12110C11 (0x12345123 - 0x00234512)
         dut.memory.mem_array[5]  = 32'h403082b3;
         // xor x6, x1, x3      -> x6 = 0x12171431 (Bitwise XOR)
         dut.memory.mem_array[6]  = 32'h0030c333;
         // or  x7, x6, x5      -> x7 = ... (Result verification below)
         dut.memory.mem_array[7]  = 32'h005363b3;
         // and x8, x7, x4      -> x8 = ... (Result verification below)
         dut.memory.mem_array[8]  = 32'h0043f433;
         // slt x9, x3, x1      -> x9 = 1 (Since x3 < x1 is true)
         dut.memory.mem_array[9]  = 32'h0011a4b3;

         // --- EXECUTION ---
         rst = 1'b1; clock(2); rst = 1'b0;
         clock(25);
         // 1. Verify LUI + ADDI
         expect_rf(32'h12345123, 1);
         // 2. Verify Shifts (SLLI, SRLI)
         expect_rf(32'h23451230, 2);
         expect_rf(32'h00234512, 3);
         // 3. Verify Arithmetic (ADD, SUB)
         expect_rf(32'h12579635, 4);
         expect_rf(32'h12110c11, 5);
         // 4. Verify Logic (XOR)
         expect_rf(32'h12171431, 6);
         // 5. Verify SLT (Set Less Than) - x3 was smaller than x1, so x9 should be 1
         expect_rf(1, 9);
         clear_imem(10);

         $display("\n============TESTCASE: IMMEDIATE INSTRUCTIONS============\n");

         // --- INITIALIZE REGISTERS FOR TESTING ---
         // x14 = 0xFFF0_0000 (-65536)
         dut.memory.mem_array[0]  = 32'hfff00737; // lui x14, 0xfff00
         // x15 = 0x0000_000F (15)
         dut.memory.mem_array[1]  = 32'h00f00793; // addi x15, x0, 15

         // --- I-TYPE INSTRUCTIONS ---
         // slti x16, x14, 10    -> x16 = 1 (Since -65536 < 10)
         dut.memory.mem_array[2]  = 32'h00a72813;
         // sltiu x17, x14, 10   -> x17 = 0 (Unsigned: 0xFFFF0000 is very large, > 10)
         dut.memory.mem_array[3]  = 32'h00a73893;
         // xori x18, x15, 0x3   -> x15(15) XOR 3 = 12 (0xC)
         dut.memory.mem_array[4]  = 32'h0037c913;
         // ori  x19, x15, 0x10  -> x15(15) OR 16 = 31 (0x1F)
         dut.memory.mem_array[5]  = 32'h0107e993;
         // andi x20, x15, 0x7   -> x15(15) AND 7 = 7
         dut.memory.mem_array[6]  = 32'h0077fa13;

         // --- SHIFT I-TYPE ---
         // srai x21, x14, 4     -> Arithmetic shift right (preserves sign bit)
         // 0xFFFF0000 >> 4      -> 0xFFFF0000 (remains same due to leading Fs)
         dut.memory.mem_array[7]  = 32'h40475a93;

         // --- R-TYPE INSTRUCTIONS ---
         // x22 = 5, x23 = -2 (0xFFFFFFFE)
         dut.memory.mem_array[8]  = 32'h00500b13; // addi x22, x0, 5
         dut.memory.mem_array[9]  = 32'hffe00b93; // addi x23, x0, -2

         // sll x24, x22, x15    -> 5 << 15 = 163840 (0x28000)
         dut.memory.mem_array[10] = 32'h00fb1c33;
         // sltu x25, x22, x23   -> Unsigned: 5 < 0xFFFFFFFE is True (1)
         dut.memory.mem_array[11] = 32'h017b3cb3;
         // srl x26, x14, x15    -> Logical shift right (x14 >> 15)
         dut.memory.mem_array[12] = 32'h00f75d33;
         // sra x27, x14, x15    -> Arithmetic shift right (x14 >>> 15)
         dut.memory.mem_array[13] = 32'h40f75db3;

         // --- EXECUTION ---
         rst = 1'b1; clock(2); rst = 1'b0;
         clock(30); // Allow cycles for all instructions

         // --- VERIFICATION ---
         expect_rf(32'h00000001, 16); // slti
         expect_rf(32'h00000000, 17); // sltiu
         expect_rf(32'h0000000C, 18); // xori
         expect_rf(32'h0000001F, 19); // ori
         expect_rf(32'h00000007, 20); // andi
         expect_rf(32'hFFFF0000, 21); // srai (Arithmetic shift preserves sign)
         expect_rf(32'h00028000, 24); // sll
         expect_rf(32'h00000001, 25); // sltu
         expect_rf(32'h0001FFE0, 26); // srl
         expect_rf(32'hFFFFFFE0, 27); // sra
         clear_imem(14) ;

         $display("\n============TEST BRANCH============");

         $display("\n========TESTCASE: BEQ (Branch Equal)========\n");
         dut.memory.mem_array[0] = 32'h00a00093; // addi x1, x0, 10   (x1 = 10)
         dut.memory.mem_array[1] = 32'h00a00113; // addi x2, x0, 10   (x2 = 10)
         dut.memory.mem_array[2] = 32'h00000513; // addi x10, x0, 0   (x10 = 0 / SAFE)
         dut.memory.mem_array[3] = 32'h00208463; // beq  x1, x2, +8   (Jump to offset 8)
         dut.memory.mem_array[4] = 32'h00100513; // addi x10, x0, 1   (x10 = 1 / FAIL / TRAP)
         dut.memory.mem_array[5] = 32'h00000013; // nop               (Landing spot)
         rst = 1'b1; clock(2); rst = 1'b0;
         clock(15);
         expect_rf(0, 10); // Expect x10 to be 0 (Branch taken)
         clear_imem(6);

         $display("\n========TESTCASE: BNE (Branch Not Equal)========\n");
         dut.memory.mem_array[0] = 32'h00a00093; // addi x1, x0, 10   (x1 = 10)
         dut.memory.mem_array[1] = 32'h01400113; // addi x2, x0, 20   (x2 = 20)
         dut.memory.mem_array[2] = 32'h00000513; // addi x10, x0, 0   (x10 = 0 / SAFE)
         dut.memory.mem_array[3] = 32'h00209463; // bne  x1, x2, +8   (Jump to offset 8)
         dut.memory.mem_array[4] = 32'h00100513; // addi x10, x0, 1   (x10 = 1 / FAIL / TRAP)
         dut.memory.mem_array[5] = 32'h00000013; // nop               (Landing spot)
         rst = 1'b1; clock(2); rst = 1'b0;
         clock(15);
         expect_rf(0, 10); // Expect x10 to be 0 (Branch taken)
         clear_imem(6);

         $display("\n========TESTCASE: BLT (Branch Less Than Signed)========\n");
         dut.memory.mem_array[0] = 32'hff600093; // addi x1, x0, -10  (x1 = -10 / 0xFFFFFFF6)
         dut.memory.mem_array[1] = 32'h00a00113; // addi x2, x0, 10   (x2 = 10)
         dut.memory.mem_array[2] = 32'h00000513; // addi x10, x0, 0   (x10 = 0 / SAFE)
         dut.memory.mem_array[3] = 32'h0020c463; // blt  x1, x2, +8   (Jump to offset 8)
         dut.memory.mem_array[4] = 32'h00100513; // addi x10, x0, 1   (x10 = 1 / FAIL / TRAP)
         dut.memory.mem_array[5] = 32'h00000013; // nop               (Landing spot)
         rst = 1'b1; clock(2); rst = 1'b0;
         clock(15);
         expect_rf(0, 10); // Expect x10 to be 0 (Branch taken)
         clear_imem(6);

         $display("\n========TESTCASE: BGE (Branch Greater Equal Signed)========\n");
         dut.memory.mem_array[0] = 32'h00a00093; // addi x1, x0, 10   (x1 = 10)
         dut.memory.mem_array[1] = 32'hff600113; // addi x2, x0, -10  (x2 = -10)
         dut.memory.mem_array[2] = 32'h00000513; // addi x10, x0, 0   (x10 = 0 / SAFE)
         dut.memory.mem_array[3] = 32'h0020d463; // bge  x1, x2, +8   (Jump to offset 8)
         dut.memory.mem_array[4] = 32'h00100513; // addi x10, x0, 1   (x10 = 1 / FAIL / TRAP)
         dut.memory.mem_array[5] = 32'h00000013; // nop               (Landing spot)
         rst = 1'b1; clock(2); rst = 1'b0;
         clock(15);
         expect_rf(0, 10); // Expect x10 to be 0 (Branch taken)
         clear_imem(6);

         $display("\n========TESTCASE: BLTU (Branch Less Than Unsigned)========\n");
         dut.memory.mem_array[0] = 32'h00a00093; // addi x1, x0, 10   (x1 = 10)
         dut.memory.mem_array[1] = 32'hff600113; // addi x2, x0, -10  (x2 = HUGE UNSIGNED NUMBER)
         dut.memory.mem_array[2] = 32'h00000513; // addi x10, x0, 0   (x10 = 0 / SAFE)
         dut.memory.mem_array[3] = 32'h0020e463; // bltu x1, x2, +8   (Jump to offset 8)
         dut.memory.mem_array[4] = 32'h00100513; // addi x10, x0, 1   (x10 = 1 / FAIL / TRAP)
         dut.memory.mem_array[5] = 32'h00000013; // nop               (Landing spot)
         rst = 1'b1; clock(2); rst = 1'b0;
         clock(15);
         expect_rf(0, 10); // Expect x10 to be 0 (Branch taken)
         clear_imem(6);

         $display("\n========TESTCASE: BGEU (Branch Greater Equal Unsigned)========\n");
         dut.memory.mem_array[0] = 32'hff600093; // addi x1, x0, -10  (x1 = HUGE UNSIGNED NUMBER)
         dut.memory.mem_array[1] = 32'h00a00113; // addi x2, x0, 10   (x2 = 10)
         dut.memory.mem_array[2] = 32'h00000513; // addi x10, x0, 0   (x10 = 0 / SAFE)
         dut.memory.mem_array[3] = 32'h0020f463; // bgeu x1, x2, +8   (Jump to offset 8)
         dut.memory.mem_array[4] = 32'h00100513; // addi x10, x0, 1   (x10 = 1 / FAIL / TRAP)
         dut.memory.mem_array[5] = 32'h00000013; // nop               (Landing spot)
         rst = 1'b1; clock(2); rst = 1'b0;
         clock(15);
         expect_rf(0, 10); // Expect x10 to be 0 (Branch taken)
         clear_imem(6);

         $display("\n========TESTCASE: JAL========\n");
         dut.memory.mem_array[0] = 32'h00000513; // addi x10, x0, 0   (x10 = 0 / SAFE)
         dut.memory.mem_array[1] = 32'h008000ef; // jal  x1, +8       (Jump to pc+8 = index 3)
         dut.memory.mem_array[2] = 32'h00100513; // addi x10, x0, 1   (x10 = 1 / FAIL / TRAP)
         dut.memory.mem_array[3] = 32'h00200513; // addi x10, x0, 2   (x10 = 2 / SUCCESS)
         rst = 1'b1; clock(2); rst = 1'b0;
         clock(15);
         expect_rf(2, 10); // Expect x10 to be 2 (Jumped successfully)
         expect_rf(8, 1);  // Expect x1 to be 8  (Link Address = Addr of the Trap)
         clear_imem(4);

         $display("\n========TESTCASE: JALR========\n");
         dut.memory.mem_array[0] = 32'h00000513; // addi x10, x0, 0   (x10 = 0 / SAFE)
         dut.memory.mem_array[1] = 32'h01000113; // addi x2, x0, 16   (x2 = 16 / Target Address)
         dut.memory.mem_array[2] = 32'h000100e7; // jalr x1, x2, 0    (Jump to x2 + 0)
         dut.memory.mem_array[3] = 32'h00100513; // addi x10, x0, 1   (x10 = 1 / FAIL / TRAP)
         dut.memory.mem_array[4] = 32'h00200513; // addi x10, x0, 2   (x10 = 2 / SUCCESS)
         rst = 1'b1; clock(2); rst = 1'b0;
         clock(15);
         expect_rf(2, 10); // Expect x10 to be 2 (Jumped successfully)
         expect_rf(12, 1); // Expect x1 to be 12 (Link Address = Addr of the Trap)
         clear_imem(5);

        $display("\n============TEST STORE/LOAD=============");

        $display("\n========TESTCASE: BYTE (LB, LBU, SB)========\n");
        // --- 1. SETUP REGISTERS ---
        // addi x1, x0, -1       -> x1 = 0xFFFFFFFF (Negative Source)
        dut.memory.mem_array[0] = 32'hfff00093;
        // addi x2, x0, 1999     -> x2 = 0x000007CF (Positive Source)
        dut.memory.mem_array[1] = 32'h7cf00113;
        // add x3, x1, x2        -> x3 = 0x000007CE (Positive Source)
        dut.memory.mem_array[2] = 32'h002081b3;

        // --- 2. STORE BYTES (SB) ---
        // sb x2, 100(x0)       -> Mem[100] = 0xCF
        dut.memory.mem_array[3] = 32'h06200223;
        // sb x1, 101(x0)       -> Mem[101] = 0xFF
        dut.memory.mem_array[4] = 32'h061002a3;
        // sb x3, 102(x0)       -> Mem[102] = 0xCE
        dut.memory.mem_array[5] = 32'h06300323;
        // sb x3, 103(x0)       -> Mem[103] = 0xCE
        dut.memory.mem_array[6] = 32'h063003a3;

        // --- 3. LOAD BACK (Negative Case - 0xFF) ---
        // lb  x3, 100(x0)      -> Load Signed. 0xFF has MSB 1. Result should be 0xFFFFFFCF.
        dut.memory.mem_array[7] = 32'h06400183;
        // lbu x4, 100(x0)      -> Load Unsigned. Result should be 0x000000CF.
        dut.memory.mem_array[8] = 32'h06404203;
        // lb x5, 101(x0)      -> Load Unsigned. Result should be 0xFFFFFFFF.
        dut.memory.mem_array[9] = 32'h06500283;
        // lbu x6, 102(x0)      -> Load Unsigned. Result should be 0x00000034.
        dut.memory.mem_array[10] = 32'h06604303;
        // lb x7, 103(x0)      -> Load Unsigned. Result should be 0x00000012.
        dut.memory.mem_array[11] = 32'h06700383;
        // lw x8, 100(x0)      -> Load full word. Result should be 0x1234FFCF.
        dut.memory.mem_array[12] = 32'h06402403;

        rst = 1'b1; clock(2); rst = 1'b0;
        clock(19);
        // --- VERIFICATION ---
        expect_rf(32'hFFFFFFCF, 3); // LB of 0xFF -> Sign Extended
        expect_rf(32'h000000CF, 4); // LBU of 0xFF -> Zero Extended
        expect_rf(32'hFFFFFFFF, 5); // LB of 0x7F -> Normal
        expect_rf(32'h000000CE, 6); // LBU of 0x7F -> Normal
        expect_rf(32'hFFFFFFCE, 7); // LBU of 0x7F -> Normal
        expect_rf(32'hCECEFFCF, 8); // LBU of 0x7F -> Normal  123407cf
        clear_imem(12);

        $display("\n========TESTCASE: HALFWORD (UPPER vs LOWER 2 BYTES)========\n");
        // --- 1. SETUP REGISTERS ---
        // addi x10, x0, 100    -> x10 = Base Address (100)
        dut.memory.mem_array[0] = 32'h06400513;
        // addi x1, x0, -1      -> x1 = 0xFFFFFFFF (Source for Lower Half)
        dut.memory.mem_array[1] = 32'hfff00093;
        // addi x2, x0, 0x555   -> x2 = 0x00000555 (Source for Upper Half)
        dut.memory.mem_array[2] = 32'h55500113;

        // sw x0, 0(x10)        -> Mem[100] = 0x00000000 (Clear the canvas)
        dut.memory.mem_array[3] = 32'h00052023;
        // sh x1, 0(x10)        -> Store lower 16 bits of x1 (0xFFFF) to [100-101]
        dut.memory.mem_array[4] = 32'h00151023;

        // sh x2, 2(x10)        -> Store lower 16 bits of x2 (0x0555) to [102-103]
        // Expected Mem: 0x0555FFFF
        // *CRITICAL CHECK*: If your byte enables are wrong, this might overwrite the 0xFFFF!
        dut.memory.mem_array[5] = 32'h00251123;

        // --- 5. VERIFY FULL WORD ---
        // lw x3, 0(x10)        -> Load full word. Expect 0x0555FFFF.
        dut.memory.mem_array[6] = 32'h00052183;

        // --- 6. VERIFY INDIVIDUAL HALVES ---
        // lh  x4, 0(x10)       -> Load Lower (Signed). 0xFFFF -> 0xFFFFFFFF
        dut.memory.mem_array[7] = 32'h00051203;
        // lhu x5, 0(x10)       -> Load Lower (Unsigned). 0xFFFF -> 0x0000FFFF
        dut.memory.mem_array[8] = 32'h00055283;
        // lh  x6, 2(x10)       -> Load Upper (Signed). 0x0555 -> 0x00000555 (Positive)
        dut.memory.mem_array[9] = 32'h00251303;

        rst = 1'b1; clock(2); rst = 1'b0;
        clock(16);
        // 1. Did the Upper Store preserve the Lower Store? (0x0555 + 0xFFFF)
        expect_rf(32'h0555FFFF, 3);
        // 2. Check Lower Half Sign Extension (MSB was 1)
        expect_rf(32'hFFFFFFFF, 4); // LH
        expect_rf(32'h0000FFFF, 5); // LHU
        // 3. Check Upper Half Sign Extension (MSB was 0)
        expect_rf(32'h00000555, 6); // LH (offset 2)
        clear_imem(10);

        $display("\n============TESTCASE HALT============");
        // addi x1, x0, -837
        // lui x2, 0xabcde
        // ecal
        // addi x1, x0, 50
        // lui x2, 34567
        dut.memory.mem_array[0] = 32'hcbb00093 ;
        dut.memory.mem_array[1] = 32'habcde137 ;
        dut.memory.mem_array[2] = 32'h00000073 ;
        dut.memory.mem_array[3] = 32'h03200093 ;
        dut.memory.mem_array[4] = 32'h34567137 ;
        rst = 1'b1 ; clock(2) ; rst = 1'b0 ;
        clock(15) ;
        expect_rf(32'hFFFFFCBB,1) ;
        expect_rf(32'hABCDE000,2) ;
        clear_imem(5) ;


//        $display("\n============TESTCASE DIVIDER============");

//        $display("\n========TESTCASE ALL-DIV1========\n") ;
//        // addi x1, x0, -837 / lui x2, 0xabcde
//        // div x3, x1, x2
//        // divu x4, x1, x2
//        // rem x5, x1, x2
//        // remu x6, x1, x2
//        dut.memory.mem_array[0] = 32'hcbb00093 ;
//        dut.memory.mem_array[1] = 32'habcde137 ;
//        dut.memory.mem_array[2] = 32'h0220c1b3 ;
//        dut.memory.mem_array[3] = 32'h0220d233 ;
//        dut.memory.mem_array[4] = 32'h0220e2b3 ;
//        dut.memory.mem_array[5] = 32'h0220f333 ;
//        rst = 1'b1 ; clock(2) ; rst = 1'b0 ;
//        clock(17) ;
//        expect_rf(32'h00000000,3) ; // div
//        expect_rf(32'h00000001,4) ; // divu
//        expect_rf(32'hFFFFFCBB,5) ; // rem
//        expect_rf(32'h54321CBB,6) ; // remu
//        clear_imem(6) ;

//        $display("\n========TESTCASE ALL-DIV2========\n") ;
//        // addi x2, x0, -837 / lui x1, 0xabcde
//        // div x3, x1, x2
//        // divu x4, x1, x2
//        // rem x5, x1, x2
//        // remu x6, x1, x2
//        dut.memory.mem_array[0] = 32'habcde0b7 ;
//        dut.memory.mem_array[1] = 32'hcbb00113 ;
//        dut.memory.mem_array[2] = 32'h0220c1b3 ;
//        dut.memory.mem_array[3] = 32'h0220d233 ;
//        dut.memory.mem_array[4] = 32'h0220e2b3 ;
//        dut.memory.mem_array[5] = 32'h0220f333 ;
//        rst = 1'b1 ; clock(2) ; rst = 1'b0 ;
//        clock(17) ;
//        expect_rf(32'h0019C06b,3) ; // div
//        expect_rf(32'h00000000,4) ; // divu
//        expect_rf(-553,5) ; // rem
//        expect_rf(32'habcde000,6) ; // remu
//        clear_imem(6) ;

//         $display("\n========TESTCASE ALL-DIV3========\n") ;
//         // addi x1, x0, 99
//         // addi x2, x0, 33
//         // divu x3, x1, x2
//         // beq x4, x5, 20
//         // add x6, x3, x1
//         // pc + 20: addi x6, x0, 36
//         // Test if div_stall và branch cùng lúc thì pc vẫn update ko bị stall (do lệnh gây stall bị tính là flush)
//         dut.memory.mem_array[0] = 32'h06300093 ;
//         dut.memory.mem_array[1] = 32'h02100113 ;
//         dut.memory.mem_array[2] = 32'h0220d1b3 ;
//         dut.memory.mem_array[3] = 32'h00209a63 ;
//         dut.memory.mem_array[4] = 32'h00118333 ;
//         dut.memory.mem_array[5] = 32'h00208233 ;
//         dut.memory.mem_array[6] = 32'h001202b3 ;
//         dut.memory.mem_array[8] = 32'h02400313 ;
//         rst = 1'b1 ; clock(2) ; rst = 1'b0 ;
//         clock(10) ;
//         expect_rf(32'h00000024,6) ; // expect branch taken, x6 = 36
//         expect_rf(32'h00000000,3) ; //chưa chia xong
//         clock(3) ;
//         expect_rf(32'h00000003,3) ;
//         clear_imem(9) ;

//         $display("\n========TESTCASE ALL-DIV4========\n") ;
//         // addi x2, x0, 100
//         // addi x3, x0, 2
//         // addi x5, x0, 5
//         // div x1, x2, x3
//         // div x4, x1, x5
//         // div x5, x2, x5
//         // Test stall 7 clk để đợi và chạy song song 2 div
//         dut.memory.mem_array[0] = 32'h06400113 ;
//         dut.memory.mem_array[1] = 32'h00200193 ;
//         dut.memory.mem_array[2] = 32'h00500293 ;
//         dut.memory.mem_array[3] = 32'h023140b3 ;
//         dut.memory.mem_array[4] = 32'h0250c233 ;
//         dut.memory.mem_array[5] = 32'h025142b3 ;
//         rst = 1'b1 ; clock(2) ; rst = 1'b0 ;
//         clock(15) ;
//         expect_rf(32'h00000032,1) ; // expect branch taken, x6 = 36
//         expect_rf(32'h00000000,4) ; //chưa chia xong
//         clock(26) ;
//         expect_rf(32'h0000000A,4) ;
//         expect_rf(32'h00000014,5) ;
//         clear_imem(6) ;

//         $display("\n========TESTCASE ALL-DIV5========\n") ;
//         // addi x2, x0, 20
//         // addi x3, x0, 5
//         // addi x4, x0, 4
//         // div x1, x2, x3
//         // beq x1, x4, 20
//         // addi x6, x0, 1
//         // pc+20: addi x7, x0, 1
//         dut.memory.mem_array[0] = 32'h01400113 ;
//         dut.memory.mem_array[1] = 32'h00500193 ;
//         dut.memory.mem_array[2] = 32'h00400213 ;
//         dut.memory.mem_array[3] = 32'h023140b3 ;
//         dut.memory.mem_array[4] = 32'h00408a63 ;
//         dut.memory.mem_array[5] = 32'h00100313 ;
//         dut.memory.mem_array[9] = 32'h00100393 ;
//         rst = 1'b1 ; clock(2) ; rst = 1'b0 ;
//         clock(15) ;
//         expect_rf(32'h00000000,7) ; // branch stall nên chưa execute xong lệnh cuối
//         clock(3) ;
//         expect_rf(32'h00000001,7) ;
//         expect_rf(32'h00000000,6) ; //branch taken nên lệnh này flush
//         clear_imem(10) ;

//       $display("\n========TESTCASE ALL-DIV6========\n") ;
//       // addi x2, x0, 20
//       // addi x3, x0, 4
//       // div x1, x2, x3
//       // addi x1, x0, 99
//       // addi x6, x1, 0
//       // addi có rd = x1 -> flush lệnh div phía trên
//       dut.memory.mem_array[0] = 32'h01400113 ;
//       dut.memory.mem_array[1] = 32'h00400193 ;
//       dut.memory.mem_array[2] = 32'h023140b3 ;
//       dut.memory.mem_array[3] = 32'h06300093 ;
//       dut.memory.mem_array[4] = 32'h00008313 ;
//       rst = 1'b1 ; clock(2) ; rst = 1'b0 ;
//       clock(10) ;
//       expect_rf(32'h00000063,6) ;
//       clear_imem(5) ;

//         $display("\n========TESTCASE DIVISOR==0========\n");
//         // addi x1, x0, 100  (Dividend = 100)
//         // add  x2, x0, x0   (Divisor = 0)
//         // divu x3, x1, x2   (Should be 0xFFFFFFFF)
//         // remu x4, x1, x2   (Should be 100 / 0x64)
//         dut.memory.mem_array[0] = 32'h06400093;
//         dut.memory.mem_array[1] = 32'h00000133;
//         dut.memory.mem_array[2] = 32'h0220d1b3;
//         dut.memory.mem_array[3] = 32'h0220f233;
//         rst = 1'b1; clock(2); rst = 1'b0;
//         clock(19); // Wait enough cycles for pipeline
//         expect_rf(32'hFFFFFFFF, 3); // DIVU by 0 = -1 (All 1s)
//         expect_rf(100, 4);          // REMU by 0 = Dividend
//         clear_imem(4);

//         $display("\n========TESTCASE MAX UNSIGNED========\n");
//         // addi x1, x0, -1   (Dividend = All 1s / Max Unsigned)
//         // addi x2, x0, 2    (Divisor = 2)
//         // divu x3, x1, x2   (Max / 2 = 0x7FFFFFFF)
//         // remu x4, x1, x2   (Max % 2 = 1)
//         dut.memory.mem_array[0] = 32'hfff00093;
//         dut.memory.mem_array[1] = 32'h00200113;
//         dut.memory.mem_array[2] = 32'h0220d1b3;
//         dut.memory.mem_array[3] = 32'h0220f233;
//         rst = 1'b1; clock(2); rst = 1'b0;
//         clock(19);
//         expect_rf(32'h7FFFFFFF, 3); // (2^32 - 1) / 2
//         expect_rf(1, 4);            // Remainder 1
//         clear_imem(4);
    end
endmodule



