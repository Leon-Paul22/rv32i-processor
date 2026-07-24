`timescale 1ns/1ps

module tb_alu_operand_mux;

    //==========================================================================
    // Parameters
    //==========================================================================
    parameter int XLEN = 32;
    parameter int NUM_RANDOM_TESTS = 100;

    //==========================================================================
    // DUT Signals
    //==========================================================================
    logic [XLEN-1:0] rs2_data_i;
    logic [XLEN-1:0] imm_i;
    logic            alu_src_i;

    logic [XLEN-1:0] operand_b_o;

    //==========================================================================
    // DUT
    //==========================================================================
    alu_operand_mux #(
        .XLEN(XLEN)
    ) dut (
        .rs2_data_i (rs2_data_i),
        .imm_i      (imm_i),
        .alu_src_i  (alu_src_i),
        .operand_b_o(operand_b_o)
    );

    //==========================================================================
    // Golden Reference Model
    //==========================================================================
    function automatic logic [XLEN-1:0] expected_output;

        input logic [XLEN-1:0] rs2;
        input logic [XLEN-1:0] imm;
        input logic            sel;

        begin
            expected_output = (sel) ? imm : rs2;
        end

    endfunction

    //==========================================================================
    // Task
    //==========================================================================
    task automatic check_output;

        logic [XLEN-1:0] expected;

        begin

            expected = expected_output(
                rs2_data_i,
                imm_i,
                alu_src_i
            );

            assert (operand_b_o === expected)
            else begin
                $error("\nFAILED");
                $display("alu_src_i   = %0b", alu_src_i);
                $display("rs2_data_i  = 0x%08h", rs2_data_i);
                $display("imm_i       = 0x%08h", imm_i);
                $display("Expected    = 0x%08h", expected);
                $display("Actual      = 0x%08h", operand_b_o);
                $finish;
            end

        end

    endtask

    //==========================================================================
    // Test Sequence
    //==========================================================================
    integer i;

    initial begin

        $display("\n========== ALU Operand MUX Test ==========");

        // Directed Test 1
        rs2_data_i = 32'hAAAAAAAA;
        imm_i      = 32'h55555555;
        alu_src_i  = 1'b0;
        #1;
        check_output();

        // Directed Test 2
        alu_src_i = 1'b1;
        #1;
        check_output();

        // Random Tests
        for(i = 0; i < NUM_RANDOM_TESTS; i++) begin

            rs2_data_i = $urandom;
            imm_i      = $urandom;
            alu_src_i  = $urandom;

            #1;

            check_output();

        end

        $display("All ALU Operand MUX tests passed!");
        $finish;

    end

endmodule