module tb_instruction_memory;

    parameter int    DEPTH            = 256;
    parameter int    INSTR_ADDR_WIDTH = 32;
    parameter int    INSTR_WIDTH      = 32;
    parameter string MEM_FILE         = "program.hex";

    localparam int MEM_ADDR_WIDTH  = $clog2(DEPTH);
    localparam int NUM_RANDOM_TESTS = 20;

    logic [INSTR_ADDR_WIDTH-1:0] pc_i;
    logic [INSTR_WIDTH-1:0]      instruction_o;

    logic [INSTR_WIDTH-1:0] golden_mem [0:DEPTH-1];
    logic [INSTR_WIDTH-1:0] expected_instruction;

    logic [MEM_ADDR_WIDTH-1:0] random_index;

    int pass_count;
    int fail_count;

    //--------------------------------------------------------------------------
    // DUT
    //--------------------------------------------------------------------------

    instruction_memory #(
        .DEPTH            (DEPTH),
        .INSTR_ADDR_WIDTH (INSTR_ADDR_WIDTH),
        .INSTR_WIDTH      (INSTR_WIDTH),
        .MEM_FILE         (MEM_FILE)
    ) dut (
        .pc_i          (pc_i),
        .instruction_o (instruction_o)
    );

    //--------------------------------------------------------------------------
    // Golden reference memory
    //--------------------------------------------------------------------------

    initial begin
        $readmemh(MEM_FILE, golden_mem);
    end

    //--------------------------------------------------------------------------
    // Task : Apply address and check instruction
    //--------------------------------------------------------------------------

    task automatic check_instruction (
        input logic [INSTR_ADDR_WIDTH-1:0] pc,
        input logic [INSTR_WIDTH-1:0]      expected
    );
    begin
        pc_i = pc;

        #1;     // Allow combinational propagation

        assert (instruction_o == expected)
            pass_count++;

        else
        begin
            fail_count++;

            $error(
                "FAIL : PC = 0x%08h, Expected = 0x%08h, Actual = 0x%08h",
                pc,
                expected,
                instruction_o
            );
        end
    end
    endtask

    //--------------------------------------------------------------------------
    // Test sequence
    //--------------------------------------------------------------------------

    initial begin

        pass_count = 0;
        fail_count = 0;

        //----------------------------------------------------------------------
        // Boundary tests
        //----------------------------------------------------------------------

        check_instruction(
            32'h00000000,
            golden_mem[0]
        );

        check_instruction(
            (DEPTH-1)*4,
            golden_mem[DEPTH-1]
        );

        //----------------------------------------------------------------------
        // Directed tests
        //----------------------------------------------------------------------

        for (int i = 0; i < 5; i++)
        begin
            expected_instruction = golden_mem[i];

            check_instruction(
                i * 4,
                expected_instruction
            );
        end

        //----------------------------------------------------------------------
        // Random tests
        //----------------------------------------------------------------------

        repeat (NUM_RANDOM_TESTS)
        begin
            random_index = $urandom_range(0, DEPTH-1);

            expected_instruction = golden_mem[random_index];

            check_instruction(
                random_index * 4,
                expected_instruction
            );
        end

        //----------------------------------------------------------------------
        // Summary
        //----------------------------------------------------------------------

        $display("\n==================================");
        $display("PASS COUNT = %0d", pass_count);
        $display("FAIL COUNT = %0d", fail_count);
        $display("==================================\n");

        $finish;

    end

endmodule