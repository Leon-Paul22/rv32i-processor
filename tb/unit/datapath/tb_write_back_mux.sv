`timescale 1ns/1ps

module tb_write_back_mux;

    //==========================================================================
    // Parameters
    //==========================================================================
    parameter int XLEN = 32;
    parameter int NUM_RANDOM_TESTS = 100;

    //==========================================================================
    // Temporary enum
    //==========================================================================
    typedef enum logic [2:0] {
        WB_ALU   = 3'b000,
        WB_MEM   = 3'b001,
        WB_PC4   = 3'b010,
        WB_AUIPC = 3'b011,
        WB_IMM   = 3'b100
    } wb_sel_t;

    //==========================================================================
    // DUT Signals
    //==========================================================================
    logic [XLEN-1:0] alu_result_i;
    logic [XLEN-1:0] mem_data_i;
    logic [XLEN-1:0] pc_plus4_i;
    logic [XLEN-1:0] pc_plus_imm_i;
    logic [XLEN-1:0] imm_i;

    wb_sel_t wb_sel_i;

    logic [XLEN-1:0] wb_data_o;

    //==========================================================================
    // DUT
    //==========================================================================
    write_back_mux #(
        .XLEN(XLEN)
    ) dut (
        .alu_result_i (alu_result_i),
        .mem_data_i   (mem_data_i),
        .pc_plus4_i   (pc_plus4_i),
        .pc_plus_imm_i(pc_plus_imm_i),
        .imm_i        (imm_i),
        .wb_sel_i     (wb_sel_i),
        .wb_data_o    (wb_data_o)
    );

    //==========================================================================
    // Golden Reference Model
    //==========================================================================
    function automatic logic [XLEN-1:0] expected_output;

        input logic [XLEN-1:0] alu_result;
        input logic [XLEN-1:0] mem_data;
        input logic [XLEN-1:0] pc4;
        input logic [XLEN-1:0] pc_imm;
        input logic [XLEN-1:0] imm;
        input wb_sel_t         sel;

        begin

            unique case (sel)

                WB_ALU   : expected_output = alu_result;
                WB_MEM   : expected_output = mem_data;
                WB_PC4   : expected_output = pc4;
                WB_AUIPC : expected_output = pc_imm;
                WB_IMM   : expected_output = imm;

                default  : expected_output = 'x;

            endcase

        end

    endfunction

    //==========================================================================
    // Task
    //==========================================================================
    task automatic check_output;

        logic [XLEN-1:0] expected;

        begin

            expected = expected_output(
                alu_result_i,
                mem_data_i,
                pc_plus4_i,
                pc_plus_imm_i,
                imm_i,
                wb_sel_i
            );

            assert (wb_data_o === expected)
            else begin

                $error("\nFAILED");

                $display("wb_sel_i      = %0d", wb_sel_i);
                $display("alu_result_i  = 0x%08h", alu_result_i);
                $display("mem_data_i    = 0x%08h", mem_data_i);
                $display("pc_plus4_i    = 0x%08h", pc_plus4_i);
                $display("pc_plus_imm_i = 0x%08h", pc_plus_imm_i);
                $display("imm_i         = 0x%08h", imm_i);

                $display("Expected      = 0x%08h", expected);
                $display("Actual        = 0x%08h", wb_data_o);

                $finish;

            end

        end

    endtask

    //==========================================================================
    // Test Sequence
    //==========================================================================
    integer i;

    initial begin

        $display("\n========== Write Back MUX Test ==========");

        // Directed Tests
        alu_result_i  = 32'h11111111;
        mem_data_i    = 32'h22222222;
        pc_plus4_i    = 32'h33333333;
        pc_plus_imm_i = 32'h44444444;
        imm_i         = 32'h55555555;

        wb_sel_i = WB_ALU;    #1; check_output();
        wb_sel_i = WB_MEM;    #1; check_output();
        wb_sel_i = WB_PC4;    #1; check_output();
        wb_sel_i = WB_AUIPC;  #1; check_output();
        wb_sel_i = WB_IMM;    #1; check_output();

        // Random Tests
        for (i = 0; i < NUM_RANDOM_TESTS; i++) begin

            alu_result_i  = $urandom;
            mem_data_i    = $urandom;
            pc_plus4_i    = $urandom;
            pc_plus_imm_i = $urandom;
            imm_i         = $urandom;

            wb_sel_i = wb_sel_t'($urandom % 5);

            #1;

            check_output();

        end

        $display("All Write Back MUX tests passed!");
        $finish;

    end

endmodule