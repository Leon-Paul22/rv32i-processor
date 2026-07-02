```systemverilog
module tb_alu;

    parameter int DATA_WIDTH = 32;

    localparam logic [DATA_WIDTH-1:0] ALL_ZEROES = '0;
    localparam logic [DATA_WIDTH-1:0] ALL_ONES   = '1;
    localparam logic [DATA_WIDTH-1:0] MAX_SIGNED =
        {1'b0, {(DATA_WIDTH-1){1'b1}}};

    logic [DATA_WIDTH-1:0] operand_a;
    logic [DATA_WIDTH-1:0] operand_b;
    alu_op_t               alu_op;

    logic [DATA_WIDTH-1:0] result;
    logic                  zero_flag;

    int total_tests;
    int passed_tests;
    int failed_tests;

    // DUT

    alu #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .operand_a (operand_a),
        .operand_b (operand_b),
        .alu_op    (alu_op),
        .result    (result),
        .zero_flag (zero_flag)
    );

    // Test task

    task automatic run_test (
        input logic [DATA_WIDTH-1:0] a,
        input logic [DATA_WIDTH-1:0] b,
        input alu_op_t               op_code,
        input logic [DATA_WIDTH-1:0] expected_result,
        input logic                  expected_zero_flag,
        input string                 test_name
    );

        operand_a = a;
        operand_b = b;
        alu_op    = op_code;

        #1;

        total_tests++;

        if ((result == expected_result) &&
            (zero_flag == expected_zero_flag))
        begin
            passed_tests++;

            $display("[PASS] %-25s Result=%h Zero=%b",
                test_name,
                result,
                zero_flag
            );
        end
        else begin
            failed_tests++;

            assert (result == expected_result)
            else
                $error(
                    "[%s] Result mismatch. Expected=%h Actual=%h",
                    test_name,
                    expected_result,
                    result
                );

            assert (zero_flag == expected_zero_flag)
            else
                $error(
                    "[%s] Zero flag mismatch. Expected=%b Actual=%b",
                    test_name,
                    expected_zero_flag,
                    zero_flag
                );
        end

    endtask

    // Stimulus

    initial begin

        operand_a    = ALL_ZEROES;
        operand_b    = ALL_ZEROES;
        alu_op       = ALU_ADD;

        total_tests  = 0;
        passed_tests = 0;
        failed_tests = 0;

        // ADD

        run_test(5, 10, ALU_ADD, 15, 0, "ADD_NORMAL");
        run_test(ALL_ONES, 1, ALU_ADD, ALL_ZEROES, 1, "ADD_WRAPAROUND");
        run_test(0, 0, ALU_ADD, 0, 1, "ADD_ZERO");

        // SUB

        run_test(10, 5, ALU_SUB, 5, 0, "SUB_NORMAL");
        run_test(5, 10, ALU_SUB, DATA_WIDTH'(32'hFFFFFFFB), 0, "SUB_NEGATIVE");
        run_test(5, 5, ALU_SUB, 0, 1, "SUB_ZERO");
        run_test(0, 1, ALU_SUB, ALL_ONES, 0, "SUB_UNDERFLOW");

        // LOGIC

        run_test(
            DATA_WIDTH'(32'hAA55AA55),
            DATA_WIDTH'(32'h0F0F0F0F),
            ALU_AND,
            DATA_WIDTH'(32'h0A050A05),
            0,
            "AND"
        );

        run_test(
            DATA_WIDTH'(32'h0F0F0F0F),
            DATA_WIDTH'(32'hA050A050),
            ALU_OR,
            DATA_WIDTH'(32'hAF5FAF5F),
            0,
            "OR"
        );

        run_test(
            ALL_ONES,
            DATA_WIDTH'(32'h0F0F0F0F),
            ALU_XOR,
            DATA_WIDTH'(32'hF0F0F0F0),
            0,
            "XOR"
        );

        // SHIFT LEFT

        run_test(DATA_WIDTH'(32'h99999999), 0,  ALU_SLL,
                 DATA_WIDTH'(32'h99999999), 0, "SLL_0");

        run_test(DATA_WIDTH'(32'h99999999), 1,  ALU_SLL,
                 DATA_WIDTH'(32'h33333332), 0, "SLL_1");

        run_test(DATA_WIDTH'(32'h99999999), 31, ALU_SLL,
                 DATA_WIDTH'(32'h80000000), 0, "SLL_31");

        // SHIFT RIGHT LOGICAL

        run_test(DATA_WIDTH'(32'h99999999), 0, ALU_SRL,
                 DATA_WIDTH'(32'h99999999), 0, "SRL_0");

        run_test(DATA_WIDTH'(32'h99999999), 1, ALU_SRL,
                 DATA_WIDTH'(32'h4CCCCCCC), 0, "SRL_1");

        run_test(DATA_WIDTH'(32'h99999999), 31, ALU_SRL,
                 1, 0, "SRL_31");

        // SHIFT RIGHT ARITHMETIC

        run_test(DATA_WIDTH'(32'h99999999), 0, ALU_SRA,
                 DATA_WIDTH'(32'h99999999), 0, "SRA_0");

        run_test(DATA_WIDTH'(32'h99999999), 1, ALU_SRA,
                 DATA_WIDTH'(32'hCCCCCCCC), 0, "SRA_1");

        run_test(DATA_WIDTH'(32'h99999999), 31, ALU_SRA,
                 ALL_ONES, 0, "SRA_31");

        // SLT

        run_test(ALL_ONES, 1, ALU_SLT, 1, 0, "SLT_NEG_POS");
        run_test(1, ALL_ONES, ALU_SLT, 0, 1, "SLT_POS_NEG");
        run_test(MAX_SIGNED, ALL_ONES, ALU_SLT, 0, 1, "SLT_OVERFLOW");
        run_test(5, 1, ALU_SLT, 0, 1, "SLT_NORMAL");
        run_test(1, 1, ALU_SLT, 0, 1, "SLT_EQUAL");

        // SLTU

        run_test(ALL_ONES, 0, ALU_SLTU, 0, 1, "SLTU_MAX_ZERO");
        run_test(1, 5, ALU_SLTU, 1, 0, "SLTU_NORMAL");
        run_test(5, 1, ALU_SLTU, 0, 1, "SLTU_NORMAL2");

        // Summary

        assert(total_tests == passed_tests + failed_tests)
        else
            $fatal("Counter mismatch");

        $display("");
        $display("======================================");
        $display("");
        $display("Total Tests  : %0d", total_tests);
        $display("");
        $display("Passed Tests : %0d", passed_tests);
        $display("");
        $display("Failed Tests : %0d", failed_tests);
        $display("");
        $display("======================================");

        $finish;

    end

endmodule

