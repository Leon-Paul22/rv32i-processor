`timescale 1ns/1ps

import alu_pkg::*;

module tb_alu_control;

    // DUT Inputs
    logic [1:0] alu_op_i;
    logic [2:0] funct3_i;
    logic [6:0] funct7_i;

    // DUT Output
    alu_op_t alu_op_o;

    // Pass/fail counters
    int pass_count;
    int fail_count;

    // DUT
    alu_control dut (
        .alu_op_i (alu_op_i),
        .funct3_i (funct3_i),
        .funct7_i (funct7_i),
        .alu_op_o (alu_op_o)
    );

    //--------------------------------------------
    // Function for calculating expected result
    //--------------------------------------------
    function automatic alu_op_t expected_alu_control(
        input logic [1:0] alu_op,
        input logic [2:0] funct3,
        input logic [6:0] funct7
    );

        expected_alu_control = ALU_ADD;

        unique case (alu_op)

            //--------------------------------------------------
            // Fixed ADD
            //--------------------------------------------------
            2'b00:
                expected_alu_control = ALU_ADD;

            //--------------------------------------------------
            // Fixed SUB
            //--------------------------------------------------
            2'b01:
                expected_alu_control = ALU_SUB;

            //--------------------------------------------------
            // R-Type Decode
            //--------------------------------------------------
            2'b10:
                unique case (funct3)

                    3'b000:
                        unique case (funct7)

                            7'b0000000 : expected_alu_control = ALU_ADD;
                            7'b0100000 : expected_alu_control = ALU_SUB;

                            default    : expected_alu_control = ALU_ADD;

                        endcase

                    3'b001 : expected_alu_control = ALU_SLL;
                    3'b010 : expected_alu_control = ALU_SLT;
                    3'b011 : expected_alu_control = ALU_SLTU;
                    3'b100 : expected_alu_control = ALU_XOR;

                    3'b101:
                        unique case (funct7)

                            7'b0000000 : expected_alu_control = ALU_SRL;
                            7'b0100000 : expected_alu_control = ALU_SRA;

                            default    : expected_alu_control = ALU_SRL;

                        endcase

                    3'b110 : expected_alu_control = ALU_OR;
                    3'b111 : expected_alu_control = ALU_AND;

                    default : expected_alu_control = ALU_ADD;

                endcase

            //--------------------------------------------------
            // I-Type Decode
            //--------------------------------------------------
            2'b11:
                unique case (funct3)

                    3'b000 : expected_alu_control = ALU_ADD;   // ADDI

                    3'b001 : expected_alu_control = ALU_SLL;   // SLLI

                    3'b010 : expected_alu_control = ALU_SLT;   // SLTI

                    3'b011 : expected_alu_control = ALU_SLTU;  // SLTIU

                    3'b100 : expected_alu_control = ALU_XOR;   // XORI

                    3'b101:
                        unique case (funct7)

                            7'b0000000 : expected_alu_control = ALU_SRL; // SRLI
                            7'b0100000 : expected_alu_control = ALU_SRA; // SRAI

                            default    : expected_alu_control = ALU_SRL;

                        endcase

                    3'b110 : expected_alu_control = ALU_OR;    // ORI

                    3'b111 : expected_alu_control = ALU_AND;   // ANDI

                    default : expected_alu_control = ALU_ADD;

                endcase

            default:
                expected_alu_control = ALU_ADD;

        endcase

    endfunction

    //--------------------------------------------
    // Self-checking task
    //--------------------------------------------
    task automatic check_operation(
        input logic [1:0] alu_op,
        input logic [2:0] funct3,
        input logic [6:0] funct7
    );

        alu_op_t expected;

        begin

            alu_op_i = alu_op;
            funct3_i = funct3;
            funct7_i = funct7;

            expected = expected_alu_control(
                            alu_op,
                            funct3,
                            funct7);

            #1;

            assert (alu_op_o == expected)
            begin

                $display(
                    "[PASS] alu_op=%b funct3=%b funct7=%b --> %s",
                    alu_op_i,
                    funct3_i,
                    funct7_i,
                    alu_op_o.name()
                );

            end
            else begin

                $error(
                    "[FAIL] alu_op=%b funct3=%b funct7=%b Expected=%s Got=%s",
                    alu_op_i,
                    funct3_i,
                    funct7_i,
                    expected.name(),
                    alu_op_o.name()
                );

            end

            if (alu_op_o == expected)
                pass_count++;
            else
                fail_count++;

        end

    endtask

    //==========================================================
    // Stimulus
    //==========================================================

    initial begin

        pass_count = 0;
        fail_count = 0;

        //-------------------------
        // Fixed ADD
        //-------------------------
        check_operation(2'b00, 3'b000, 7'b0000000);

        //-------------------------
        // Fixed SUB
        //-------------------------
        check_operation(2'b01, 3'b000, 7'b0000000);

        //-------------------------
        // R-Type Instructions
        //-------------------------
        check_operation(2'b10, 3'b000, 7'b0000000); // ADD
        check_operation(2'b10, 3'b000, 7'b0100000); // SUB

        check_operation(2'b10, 3'b001, 7'b0000000); // SLL

        check_operation(2'b10, 3'b010, 7'b0000000); // SLT

        check_operation(2'b10, 3'b011, 7'b0000000); // SLTU

        check_operation(2'b10, 3'b100, 7'b0000000); // XOR

        check_operation(2'b10, 3'b101, 7'b0000000); // SRL
        check_operation(2'b10, 3'b101, 7'b0100000); // SRA

        check_operation(2'b10, 3'b110, 7'b0000000); // OR

        check_operation(2'b10, 3'b111, 7'b0000000); // AND

        //-------------------------
        // I-Type Instructions
        //-------------------------
        check_operation(2'b11, 3'b000, 7'b0000000); // ADDI

        check_operation(2'b11, 3'b001, 7'b0000000); // SLLI

        check_operation(2'b11, 3'b010, 7'b0000000); // SLTI

        check_operation(2'b11, 3'b011, 7'b0000000); // SLTIU

        check_operation(2'b11, 3'b100, 7'b0000000); // XORI

        check_operation(2'b11, 3'b101, 7'b0000000); // SRLI
        check_operation(2'b11, 3'b101, 7'b0100000); // SRAI

        check_operation(2'b11, 3'b110, 7'b0000000); // ORI

        check_operation(2'b11, 3'b111, 7'b0000000); // ANDI

        //-------------------------
        // Illegal Combinations
        //-------------------------

        // R-Type
        check_operation(2'b10, 3'b000, 7'b1111111);
        check_operation(2'b10, 3'b101, 7'b1111111);

        // I-Type
        check_operation(2'b11, 3'b000, 7'b1111111);
        check_operation(2'b11, 3'b101, 7'b1111111);

        //-------------------------
        // Summary
        //-------------------------

        $display("\n==================================");
        $display("PASS COUNT = %0d", pass_count);
        $display("FAIL COUNT = %0d", fail_count);
        $display("==================================\n");

        assert (fail_count == 0)
            else $fatal("ALU Control testbench FAILED");

        $finish;

    end

endmodule