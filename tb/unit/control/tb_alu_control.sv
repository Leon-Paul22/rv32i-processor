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
    //Function for calculating expected result
    //--------------------------------------------
function automatic alu_op_t expected_alu_control(
    input logic [1:0] alu_op,
    input logic [2:0] funct3,
    input logic [6:0] funct7
);

    expected_alu_control = ALU_ADD;

    unique case (alu_op)

        2'b00:
            expected_alu_control = ALU_ADD;

        2'b01:
            expected_alu_control = ALU_SUB;

        2'b10:
            unique case (funct3)

                3'b000:
                    unique case (funct7)

                        7'b0000000:
                            expected_alu_control = ALU_ADD;

                        7'b0100000:
                            expected_alu_control = ALU_SUB;

                    endcase

                3'b001:
                    expected_alu_control = ALU_SLL;

                3'b010:
                    expected_alu_control = ALU_SLT;

                3'b011:
                    expected_alu_control = ALU_SLTU;

                3'b100:
                    expected_alu_control = ALU_XOR;

                3'b101:
                    unique case (funct7)

                        7'b0000000:
                            expected_alu_control = ALU_SRL;

                        7'b0100000:
                            expected_alu_control = ALU_SRA;

                    endcase

                3'b110:
                    expected_alu_control = ALU_OR;

                3'b111:
                    expected_alu_control = ALU_AND;

            endcase

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
 
    // Stimulus

    initial begin

        pass_count = 0;
        fail_count = 0;

        // Load/Store

        check_operation(2'b00, 3'b000, 7'b0000000);

        // Branch

        check_operation(2'b01, 3'b000, 7'b0000000);

        // Arithmetic Instructions

        check_operation(2'b10, 3'b000, 7'b0000000);
        check_operation(2'b10, 3'b000, 7'b0100000);

        check_operation(2'b10, 3'b001, 7'b0000000);

        check_operation(2'b10, 3'b010, 7'b0000000);

        check_operation(2'b10, 3'b011, 7'b0000000);

        check_operation(2'b10, 3'b100, 7'b0000000);

        check_operation(2'b10, 3'b101, 7'b0000000);
        check_operation(2'b10, 3'b101, 7'b0100000);

        check_operation(2'b10, 3'b110, 7'b0000000);

        check_operation(2'b10, 3'b111, 7'b0000000);

        // Illegal combinations

        check_operation(2'b10, 3'b000, 7'b1111111);

        check_operation(2'b10, 3'b101, 7'b1111111);

        check_operation(2'b11, 3'b000, 7'b0000000);

        // Summary

        $display("\n==================================");
        $display("PASS COUNT = %0d", pass_count);
        $display("FAIL COUNT = %0d", fail_count);
        $display("==================================\n");

        assert (fail_count == 0)
            else $fatal("ALU Control testbench FAILED");

        $finish;

    end

endmodule