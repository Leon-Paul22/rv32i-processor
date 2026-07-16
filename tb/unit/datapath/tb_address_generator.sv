`timescale 1ns/1ps

module tb_address_generator;

    parameter int XLEN       = 32;
    parameter int ADDR_WIDTH = XLEN;
    parameter int NUM_RANDOM_TESTS = 100;

    // DUT Signals
    logic [ADDR_WIDTH-1:0] pc_i;
    logic [XLEN-1:0]       imm_i;
    logic [XLEN-1:0]       rs1_data_i;

    logic [ADDR_WIDTH-1:0] pc_plus4_o;
    logic [ADDR_WIDTH-1:0] pc_plus_imm_o;
    logic [ADDR_WIDTH-1:0] rs1_plus_imm_o;

    int pass_count = 0;
    int fail_count = 0;

    // DUT
    address_generator #(
        .XLEN(XLEN),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .pc_i(pc_i),
        .imm_i(imm_i),
        .rs1_data_i(rs1_data_i),
        .pc_plus4_o(pc_plus4_o),
        .pc_plus_imm_o(pc_plus_imm_o),
        .rs1_plus_imm_o(rs1_plus_imm_o)
    );

    // ---------------- Reference Model ----------------

    function automatic logic [ADDR_WIDTH-1:0] expected_pc_plus4(
        input logic [ADDR_WIDTH-1:0] pc
    );
        expected_pc_plus4 = pc + ADDR_WIDTH'(4);
    endfunction

    function automatic logic [ADDR_WIDTH-1:0] expected_pc_plus_imm(
        input logic [ADDR_WIDTH-1:0] pc,
        input logic [XLEN-1:0] imm
    );
        expected_pc_plus_imm = pc + imm;
    endfunction

    function automatic logic [ADDR_WIDTH-1:0] expected_rs1_plus_imm(
        input logic [XLEN-1:0] rs1,
        input logic [XLEN-1:0] imm
    );
        localparam logic [XLEN-1:0] JALR_ALIGN_MASK =
            {{(XLEN-1){1'b1}},1'b0};

        expected_rs1_plus_imm = (rs1 + imm) & JALR_ALIGN_MASK;
    endfunction

    // ---------------- Verification Tasks ----------------

    task automatic check_outputs;
        logic [ADDR_WIDTH-1:0] exp_pc4;
        logic [ADDR_WIDTH-1:0] exp_pcimm;
        logic [ADDR_WIDTH-1:0] exp_rs1imm;

        begin
            exp_pc4    = expected_pc_plus4(pc_i);
            exp_pcimm  = expected_pc_plus_imm(pc_i, imm_i);
            exp_rs1imm = expected_rs1_plus_imm(rs1_data_i, imm_i);

            assert (pc_plus4_o == exp_pc4)
            else begin
                $error("PC+4 mismatch Exp=%h Got=%h", exp_pc4, pc_plus4_o);
                fail_count++;
            end

            assert (pc_plus_imm_o == exp_pcimm)
            else begin
                $error("PC+IMM mismatch Exp=%h Got=%h", exp_pcimm, pc_plus_imm_o);
                fail_count++;
            end

            assert (rs1_plus_imm_o == exp_rs1imm)
            else begin
                $error("RS1+IMM mismatch Exp=%h Got=%h", exp_rs1imm, rs1_plus_imm_o);
                fail_count++;
            end

            if ((pc_plus4_o == exp_pc4) &&
                (pc_plus_imm_o == exp_pcimm) &&
                (rs1_plus_imm_o == exp_rs1imm))
                pass_count++;
        end
    endtask

    task automatic apply_inputs(
        input logic [ADDR_WIDTH-1:0] pc,
        input logic [XLEN-1:0] imm,
        input logic [XLEN-1:0] rs1
    );
    begin
        pc_i       = pc;
        imm_i      = imm;
        rs1_data_i = rs1;
        #1;
        check_outputs();
    end
    endtask

    task automatic run_directed_tests;
    begin
        $display("Running Directed Tests...");
        apply_inputs('0, '0, '0);
        apply_inputs(32'h0000_0004, 32'd8, 32'd16);
        apply_inputs(32'hFFFF_FFFC, 32'd4, 32'hFFFF_FFFF);
        apply_inputs(32'h1000_0000, -32'sd4, 32'h1234_5678);
        apply_inputs(32'h0000_0008, 32'd3, 32'd5);
        apply_inputs(32'hAAAA_AAAA, 32'h5555_5555, 32'hFFFF_FFFF);
    end
    endtask

    task automatic run_random_tests;
        int i;
    begin
        $display("Running Random Tests...");
        for (i = 0; i < NUM_RANDOM_TESTS; i++) begin
            apply_inputs($urandom, $urandom, $urandom);
        end
    end
    endtask

    initial begin
        $dumpfile("tb_address_generator.vcd");
        $dumpvars(0, tb_address_generator);

        run_directed_tests();
        run_random_tests();

        $display("--------------------------------");
        $display("Address Generator Test Summary");
        $display("Pass = %0d", pass_count);
        $display("Fail = %0d", fail_count);
        $display("--------------------------------");

        $finish;
    end

endmodule
