//==============================================================================
// tb_rv32i_processor.sv
//==============================================================================
//
// Testbench for the Final Single-Cycle RV32I Processor (rv32i_processor.sv).
//
// main_control IS inside this DUT (unlike tb_rv32i_datapath.sv, which
// deliberately excludes it), and the DUT exposes no ports beyond
// clk_i/rst_i. So this testbench works differently from the other two:
// there's nothing to drive directly and nothing to force. A short
// instruction sequence ("program") is backdoor-loaded into instruction
// memory, the processor runs it for real - PC genuinely free-running,
// driven by main_control's real decode - and once it's had time to
// complete, the resulting architectural state (registers, memory) is
// checked against hand-computed expected values.
//
// This is simpler than tracking a shadow model instruction-by-instruction:
// each program is short and known, so the expected final state can just be
// worked out directly, the same way you'd hand-check a short assembly
// program.
//
//==============================================================================

import rv32i_pkg::*;
import alu_pkg::*;
import rv32i_model_pkg::*;

`timescale 1ns/1ps

module tb_rv32i_processor;

    import rv32i_pkg::*;
    import alu_pkg::*;
    import rv32i_model_pkg::*;

    //==========================================================================
    // Parameters
    //==========================================================================

    localparam int    XLEN       = 32;
    localparam int    ADDR_WIDTH = 32;
    localparam int    IMEM_DEPTH = 256;
    localparam string IMEM_FILE  = "program.hex";
    localparam int    DMEM_DEPTH = 1024;

    localparam int IMEM_WORD_BITS = $clog2(IMEM_DEPTH);
    localparam int DMEM_WORD_BITS = $clog2(DMEM_DEPTH);

    //==========================================================================
    // Clock / Reset
    //==========================================================================

    logic clk;
    logic rst;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    //==========================================================================
    // Test Bookkeeping
    //==========================================================================

    int unsigned pass_count = 0;
    int unsigned fail_count = 0;

    //==========================================================================
    // Functional Coverage
    //==========================================================================
    // A different focus from tb_rv32i_datapath.sv's covergroup on purpose:
    // that one measures opcode coverage with a forced PC, one instruction
    // at a time. Here the PC genuinely free-runs off main_control's real
    // decode, so what's worth covering is whether every control-flow
    // mechanism actually got exercised end-to-end.
    //==========================================================================

    pc_src_t cov_pc_src;

    covergroup cg_control_flow;
        cp_pc_src : coverpoint cov_pc_src {
            bins seq    = {PC_SEQ};
            bins branch = {PC_BRANCH};
            bins jal    = {PC_JAL};
            bins jalr   = {PC_JALR};
        }
    endgroup

    cg_control_flow cg = new();

    //==========================================================================
    // DUT Instantiation
    //==========================================================================

    rv32i_processor #(
        .XLEN       (XLEN),
        .ADDR_WIDTH (ADDR_WIDTH),
        .IMEM_DEPTH (IMEM_DEPTH),
        .IMEM_FILE  (IMEM_FILE),
        .DMEM_DEPTH (DMEM_DEPTH),
        .RESET_ADDR ('0)
    ) dut (
        .clk_i (clk),
        .rst_i (rst)
    );

    //==========================================================================
    // Backdoor Access Helpers
    //==========================================================================
    // rv32i_processor exposes only clk_i/rst_i, so every signal worth
    // checking is reached hierarchically.
    //==========================================================================

    task automatic load_instruction(logic [ADDR_WIDTH-1:0] addr, logic [31:0] instr_word);
        dut.u_rv32i_datapath.u_instruction_memory.instr_mem[addr[IMEM_WORD_BITS+1:2]] = instr_word;
    endtask

    function automatic logic [31:0] read_register(logic [4:0] addr);
        return (addr == 5'd0) ? 32'b0 : dut.u_rv32i_datapath.u_register_file.reg_arr[addr];
    endfunction

    function automatic logic [31:0] read_data_memory_word(logic [ADDR_WIDTH-1:0] addr);
        return dut.u_rv32i_datapath.u_data_memory.mem[addr[DMEM_WORD_BITS+1:2]];
    endfunction

    //==========================================================================
    // Reset
    //==========================================================================

    task automatic reset_dut();
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst = 1'b0;
        // No extra @(posedge clk) here - pc is already RESET_ADDR the
        // instant rst deasserts. An extra edge would let the DUT execute
        // the first instruction before the program even starts running.
    endtask

    //==========================================================================
    // Concurrent Assertion
    //==========================================================================
    // Checks something tb_rv32i_datapath.sv's testbench structurally can't:
    // that rst_i actually propagates two levels down (processor -> datapath
    // -> program_counter) to reset the real pc.
    //==========================================================================

    ASSERT_RESET_PROPAGATES: assert property (
        @(posedge clk) rst |-> (dut.u_rv32i_datapath.pc == '0)
    ) else $error("rst_i did not propagate to reset pc through the full hierarchy");

    //==========================================================================
    // check_reg() / check_mem()
    //==========================================================================

    task automatic check_reg(string program_name, logic [4:0] addr, logic [31:0] expected);
        logic [31:0] actual;
        actual = read_register(addr);
        if (actual === expected) begin
            pass_count++;
        end else begin
            $display("FAIL [%0s] x%0d expected=%08h actual=%08h", program_name, addr, expected, actual);
            fail_count++;
        end
    endtask

    task automatic check_mem(string program_name, logic [31:0] addr, logic [31:0] expected);
        logic [31:0] actual;
        actual = read_data_memory_word(addr);
        if (actual === expected) begin
            pass_count++;
        end else begin
            $display("FAIL [%0s] mem[%0h] expected=%08h actual=%08h", program_name, addr, expected, actual);
            fail_count++;
        end
    endtask

    //==========================================================================
    // run_program()
    //   Loads a program at RESET_ADDR, resets, then lets it run for
    //   num_cycles real clocks (main_control decoding, PC free-running).
    //   Coverage is sampled each cycle by watching main_control's real
    //   pc_src output - a bonus visibility into the DUT's own decode,
    //   since nothing here drives pc_src directly.
    //==========================================================================

    task automatic run_program(logic [31:0] prog_words[], string program_name, int num_cycles);

        $display("  [Program] %0s", program_name);

        for (int i = 0; i < prog_words.size(); i++)
            load_instruction(i * 4, prog_words[i]);

        reset_dut();

        repeat (num_cycles) begin
            cov_pc_src = dut.u_main_control.pc_src_o;
            cg.sample();
            @(posedge clk);
        end

        #1; // Let the last edge's writes settle before checking

    endtask

    //==========================================================================
    // Directed Programs
    //==========================================================================
    // One program per instruction class that has real control-flow or
    // multi-instruction behavior worth testing end-to-end. R-type/I-type
    // arithmetic is folded into "A", since a single ADD in isolation has
    // nothing new to prove here beyond what tb_rv32i_datapath.sv already
    // covers - what's new at this level is real fetch/decode/execute/
    // writeback across real cycles, with real main_control-driven control
    // flow.
    //==========================================================================

    task automatic run_directed_programs();

        logic [31:0] prog[];

        $display("========================================================");
        $display(" Directed Programs");
        $display("========================================================");

        //----------------------------------------------------------------------
        // A: ALU basics - x1=10; x2=20; x3=x1+x2=30
        //----------------------------------------------------------------------
        prog = new[3];
        prog[0] = encode_instruction(OPCODE_ITYPE, 3'b000, 7'b0, 5'd0, 5'd0, 5'd1, 32'd10); // ADDI x1,x0,10
        prog[1] = encode_instruction(OPCODE_ITYPE, 3'b000, 7'b0, 5'd0, 5'd0, 5'd2, 32'd20); // ADDI x2,x0,20
        prog[2] = encode_instruction(OPCODE_RTYPE, 3'b000, 7'b0, 5'd1, 5'd2, 5'd3, 32'd0);  // ADD  x3,x1,x2
        run_program(prog, "A: ALU basics", 3);
        check_reg("A", 5'd1, 32'd10);
        check_reg("A", 5'd2, 32'd20);
        check_reg("A", 5'd3, 32'd30);

        //----------------------------------------------------------------------
        // B: LOAD/STORE roundtrip - mem[100] = 999, then load it back
        //----------------------------------------------------------------------
        prog = new[4];
        prog[0] = encode_instruction(OPCODE_ITYPE, 3'b000, 7'b0, 5'd0, 5'd0, 5'd1, 32'd100); // ADDI x1,x0,100
        prog[1] = encode_instruction(OPCODE_ITYPE, 3'b000, 7'b0, 5'd0, 5'd0, 5'd2, 32'd999); // ADDI x2,x0,999
        prog[2] = encode_instruction(OPCODE_STORE, F3_SW,  7'b0, 5'd1, 5'd2, 5'd0, 32'd0);   // SW   x2,0(x1)
        prog[3] = encode_instruction(OPCODE_LOAD,  F3_LW,  7'b0, 5'd1, 5'd0, 5'd3, 32'd0);   // LW   x3,0(x1)
        run_program(prog, "B: LOAD/STORE roundtrip", 4);
        check_reg("B", 5'd3, 32'd999);
        check_mem("B", 32'd100, 32'd999);

        //----------------------------------------------------------------------
        // C: BRANCH taken - equal operands, so the NOP at +12 is skipped
        //----------------------------------------------------------------------
        prog = new[5];
        prog[0] = encode_instruction(OPCODE_ITYPE,  3'b000, 7'b0, 5'd0, 5'd0, 5'd1, 32'd5);   // ADDI x1,x0,5
        prog[1] = encode_instruction(OPCODE_ITYPE,  3'b000, 7'b0, 5'd0, 5'd0, 5'd2, 32'd5);   // ADDI x2,x0,5
        prog[2] = encode_instruction(OPCODE_BRANCH, F3_BEQ, 7'b0, 5'd1, 5'd2, 5'd0, 32'd8);   // BEQ x1,x2,+8
        prog[3] = encode_instruction(OPCODE_ITYPE,  3'b000, 7'b0, 5'd0, 5'd0, 5'd0, 32'd0);   // NOP (skipped)
        prog[4] = encode_instruction(OPCODE_ITYPE,  3'b000, 7'b0, 5'd0, 5'd0, 5'd3, 32'd222); // ADDI x3,x0,222
        run_program(prog, "C: BRANCH taken", 4);
        check_reg("C", 5'd3, 32'd222);

        //----------------------------------------------------------------------
        // D: BRANCH not-taken - unequal operands, falls through normally
        //----------------------------------------------------------------------
        prog = new[4];
        prog[0] = encode_instruction(OPCODE_ITYPE,  3'b000, 7'b0, 5'd0, 5'd0, 5'd1, 32'd5);   // ADDI x1,x0,5
        prog[1] = encode_instruction(OPCODE_ITYPE,  3'b000, 7'b0, 5'd0, 5'd0, 5'd2, 32'd7);   // ADDI x2,x0,7
        prog[2] = encode_instruction(OPCODE_BRANCH, F3_BEQ, 7'b0, 5'd1, 5'd2, 5'd0, 32'd8);   // BEQ x1,x2,+8
        prog[3] = encode_instruction(OPCODE_ITYPE,  3'b000, 7'b0, 5'd0, 5'd0, 5'd3, 32'd333); // ADDI x3,x0,333
        run_program(prog, "D: BRANCH not-taken", 4);
        check_reg("D", 5'd3, 32'd333);

        //----------------------------------------------------------------------
        // E: JAL - x1 gets the return address (4), execution jumps to +12
        //----------------------------------------------------------------------
        prog = new[4];
        prog[0] = encode_instruction(OPCODE_JAL,   3'b0,   7'b0, 5'd0, 5'd0, 5'd1, 32'd12); // JAL x1,+12
        prog[1] = encode_instruction(OPCODE_ITYPE, 3'b000, 7'b0, 5'd0, 5'd0, 5'd0, 32'd0);  // NOP (skipped)
        prog[2] = encode_instruction(OPCODE_ITYPE, 3'b000, 7'b0, 5'd0, 5'd0, 5'd0, 32'd0);  // NOP (skipped)
        prog[3] = encode_instruction(OPCODE_ITYPE, 3'b000, 7'b0, 5'd0, 5'd0, 5'd3, 32'd42); // ADDI x3,x0,42
        run_program(prog, "E: JAL", 2);
        check_reg("E", 5'd1, 32'd4);
        check_reg("E", 5'd3, 32'd42);

        //----------------------------------------------------------------------
        // F: JALR - jump to x1+0, where x1 was set to 12 beforehand
        //----------------------------------------------------------------------
        prog = new[4];
        prog[0] = encode_instruction(OPCODE_ITYPE, 3'b000, 7'b0, 5'd0, 5'd0, 5'd1, 32'd12); // ADDI x1,x0,12
        prog[1] = encode_instruction(OPCODE_JALR,  3'b000, 7'b0, 5'd1, 5'd0, 5'd2, 32'd0);  // JALR x2,x1,0
        prog[2] = encode_instruction(OPCODE_ITYPE, 3'b000, 7'b0, 5'd0, 5'd0, 5'd0, 32'd0);  // NOP (skipped)
        prog[3] = encode_instruction(OPCODE_ITYPE, 3'b000, 7'b0, 5'd0, 5'd0, 5'd3, 32'd77); // ADDI x3,x0,77
        run_program(prog, "F: JALR", 3);
        check_reg("F", 5'd1, 32'd12);
        check_reg("F", 5'd2, 32'd8);
        check_reg("F", 5'd3, 32'd77);

        //----------------------------------------------------------------------
        // G: LUI/AUIPC
        //----------------------------------------------------------------------
        prog = new[2];
        prog[0] = encode_instruction(OPCODE_LUI,   3'b0, 7'b0, 5'd0, 5'd0, 5'd1, 32'h12345); // LUI x1,0x12345
        prog[1] = encode_instruction(OPCODE_AUIPC, 3'b0, 7'b0, 5'd0, 5'd0, 5'd2, 32'h1);     // AUIPC x2,0x1
        run_program(prog, "G: LUI/AUIPC", 2);
        check_reg("G", 5'd1, 32'h1234_5000);
        check_reg("G", 5'd2, 32'h0000_1004); // pc(4) + 0x1000

    endtask

    //==========================================================================
    // Coverage / Summary Report
    //==========================================================================

    task automatic print_summary();
        $display("==========================================================");
        $display(" Coverage / Summary Report");
        $display("==========================================================");
        $display(" Control-Flow Coverage : %0.2f%%", cg.get_coverage());
        $display("----------------------------------------------------------");
        $display(" Pass                  : %0d", pass_count);
        $display(" Fail                  : %0d", fail_count);
        $display("==========================================================");
        if (fail_count == 0)
            $display(" RESULT: ALL TESTS PASSED");
        else
            $display(" RESULT: %0d TEST(S) FAILED", fail_count);
        $display("==========================================================");
    endtask

    //==========================================================================
    // Initial Block
    //==========================================================================

    initial begin

        $display("==========================================================");
        $display(" RV32I Processor Testbench");
        $display("==========================================================");

        run_directed_programs();

        print_summary();

        $finish;

    end

endmodule
