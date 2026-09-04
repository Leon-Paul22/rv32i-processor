//==============================================================================
// tb_rv32i_datapath.sv
//==============================================================================
//
// Testbench for the RV32I Top-Level Datapath (rv32i_datapath.sv).
//
// main_control is NOT part of this DUT, so this testbench drives control
// signals itself: for each test instruction, rv32i_model_pkg::decode_control()
// computes what a correct main_control would produce, and that's driven
// straight into the datapath's control-signal inputs. This keeps the
// datapath verified independently of main_control (already verified on its
// own in tb_main_control.sv).
//
// This DUT is stateful (register file, data memory, PC) and has almost no
// externally visible ports, so checking needs hierarchical (backdoor)
// access into DUT internals - both to observe results and, for the
// instruction memory (a ROM with no write port), to inject stimulus.
//
// Checking is kept to the signals that actually matter architecturally:
// next_pc, the eventual register write, and the eventual memory write.
// Those are downstream of every intermediate signal (ALU result, branch
// flags, immediate, etc.), so a bug anywhere upstream still gets caught -
// this just doesn't try to pinpoint every internal wire individually.
//
//==============================================================================

import rv32i_pkg::*;
import alu_pkg::*;
import rv32i_model_pkg::*;

//==============================================================================
// dp_transaction
//==============================================================================

class dp_transaction;

    rand logic [6:0]  opcode = '0;
    rand logic [2:0]  funct3 = '0;
    rand logic [6:0]  funct7 = '0;

    rand logic [4:0]  rs1_addr = '0;
    rand logic [4:0]  rs2_addr = '0;
    rand logic [4:0]  rd_addr  = '0;

    rand logic [31:0] imm_raw = '0;

    rand logic [31:0] rs1_val = '0;
    rand logic [31:0] rs2_val = '0;
    rand logic [31:0] mem_preload_val = '0;

    //--------------------------------------------------------------------------
    // Constraints
    //--------------------------------------------------------------------------
    // opcode_c uses a weighted (dist) constraint instead of a flat inside
    // set: R-type/I-type ALU instructions dominate most real code, so
    // they're weighted heavier, while control-flow and upper-immediate
    // instructions are rarer but still guaranteed to appear (every weight
    // is > 0). ":=" gives that exact bin its share of the total weight;
    // ":/" would instead spread a shared weight evenly across a range.
    //
    // LOAD/STORE are constrained to word access (F3_LW/F3_SW) - see the
    // scope note in rv32i_model_pkg.sv.
    //--------------------------------------------------------------------------

    constraint opcode_c {
        opcode dist {
            OPCODE_RTYPE  := 4,
            OPCODE_ITYPE  := 4,
            OPCODE_LOAD   := 2,
            OPCODE_STORE  := 2,
            OPCODE_BRANCH := 2,
            OPCODE_JAL    := 1,
            OPCODE_JALR   := 1,
            OPCODE_LUI    := 1,
            OPCODE_AUIPC  := 1
        };
    }

    constraint load_c    { if (opcode == OPCODE_LOAD)  funct3 == F3_LW; }
    constraint store_c   { if (opcode == OPCODE_STORE) funct3 == F3_SW; }
    constraint jalr_c     { if (opcode == OPCODE_JALR) funct3 == 3'b000; }

    constraint branch_c {
        if (opcode == OPCODE_BRANCH)
            funct3 inside {F3_BEQ, F3_BNE, F3_BLT, F3_BGE, F3_BLTU, F3_BGEU};
    }

    // Keeps funct7 (R-type) and the shift-amount immediate's upper bits
    // (I-type SLLI/SRLI/SRAI) at real, legal RV32I encodings.
    constraint funct7_c {
        if (opcode == OPCODE_RTYPE) {
            if (funct3 == 3'b000 || funct3 == 3'b101)
                funct7 inside {7'b0000000, 7'b0100000};
            else
                funct7 == 7'b0000000;
        }
        if (opcode == OPCODE_ITYPE && funct3 == 3'b001)
            imm_raw[11:5] == 7'b0000000;
        if (opcode == OPCODE_ITYPE && funct3 == 3'b101)
            imm_raw[11:5] inside {7'b0000000, 7'b0100000};
    }

    function automatic logic [31:0] build_instruction();
        return rv32i_model_pkg::encode_instruction(
            opcode, funct3, funct7, rs1_addr, rs2_addr, rd_addr, imm_raw
        );
    endfunction

    function automatic string label();
        unique case (opcode)
            OPCODE_RTYPE:  return "R-Type";
            OPCODE_ITYPE:  return "I-Type ALU";
            OPCODE_LOAD:   return "LOAD";
            OPCODE_STORE:  return "STORE";
            OPCODE_BRANCH: return "BRANCH";
            OPCODE_JAL:    return "JAL";
            OPCODE_JALR:   return "JALR";
            OPCODE_LUI:    return "LUI";
            OPCODE_AUIPC:  return "AUIPC";
            default:       return "UNKNOWN";
        endcase
    endfunction

endclass

//==============================================================================
// Testbench Module
//==============================================================================

`timescale 1ns/1ps

module tb_rv32i_datapath;

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

    localparam int NUM_RANDOM_TESTS = 300;

    // A fixed test address. dut.pc is force-driven here so each
    // transaction is one isolated, independently-checkable instruction
    // rather than part of a running program (that style belongs to
    // tb_rv32i_processor.sv, which tests real program execution instead).
    localparam logic [ADDR_WIDTH-1:0] TEST_PC = 32'h0000_0040;

    //==========================================================================
    // Clock / Reset
    //==========================================================================

    logic clk;
    logic rst;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    //==========================================================================
    // Control-Signal Inputs (driven directly - stands in for main_control)
    //==========================================================================

    logic             pc_enable;
    logic             reg_write;
    logic             alu_src;
    alu_ctrl_sel_t    alu_op;
    logic             mem_read;
    logic             mem_write;
    mem_access_size_t access_size;
    logic             load_unsigned;
    wb_sel_t          wb_sel;
    pc_src_t          pc_src;
    branch_type_t     branch_type;
    logic [XLEN-1:0]  instruction;

    //==========================================================================
    // Test Bookkeeping
    //==========================================================================

    int unsigned pass_count          = 0;
    int unsigned fail_count          = 0;
    int unsigned directed_test_count = 0;
    int unsigned random_test_count   = 0;

    //==========================================================================
    // Functional Coverage
    //==========================================================================

    logic [6:0] cov_opcode;

    covergroup cg_datapath;
        cp_opcode : coverpoint cov_opcode {
            bins rtype  = {OPCODE_RTYPE};
            bins itype  = {OPCODE_ITYPE};
            bins load   = {OPCODE_LOAD};
            bins store  = {OPCODE_STORE};
            bins branch = {OPCODE_BRANCH};
            bins jalr   = {OPCODE_JALR};
            bins jal    = {OPCODE_JAL};
            bins lui    = {OPCODE_LUI};
            bins auipc  = {OPCODE_AUIPC};
        }
    endgroup

    cg_datapath cg = new();

    //==========================================================================
    // DUT Instantiation
    //==========================================================================

    rv32i_datapath #(
        .XLEN       (XLEN),
        .ADDR_WIDTH (ADDR_WIDTH),
        .IMEM_DEPTH (IMEM_DEPTH),
        .IMEM_FILE  (IMEM_FILE),
        .DMEM_DEPTH (DMEM_DEPTH),
        .RESET_ADDR ('0)
    ) dut (
        .clk_i (clk),
        .rst_i (rst),
        .pc_enable_i (pc_enable),
        .reg_write_i     (reg_write),
        .alu_src_i       (alu_src),
        .alu_op_i        (alu_op),
        .mem_read_i      (mem_read),
        .mem_write_i     (mem_write),
        .access_size_i   (access_size),
        .load_unsigned_i (load_unsigned),
        .wb_sel_i        (wb_sel),
        .pc_src_i        (pc_src),
        .branch_type_i   (branch_type),
        .instruction_o (instruction)
    );

    //==========================================================================
    // Backdoor Access Helpers
    //==========================================================================
    // instruction_memory has no write port (it's a ROM loaded once via
    // $readmemh), so stimulus injection needs to write its array directly.
    // Checking the register file/data memory likewise needs direct reads.
    //==========================================================================

    task automatic load_instruction(logic [ADDR_WIDTH-1:0] addr, logic [31:0] instr_word);
        dut.u_instruction_memory.instr_mem[addr[IMEM_WORD_BITS+1:2]] = instr_word;
    endtask

    task automatic preload_register(logic [4:0] addr, logic [31:0] value);
        if (addr != 5'd0)
            dut.u_register_file.reg_arr[addr] = value;
    endtask

    function automatic logic [31:0] read_register(logic [4:0] addr);
        return (addr == 5'd0) ? 32'b0 : dut.u_register_file.reg_arr[addr];
    endfunction

    task automatic preload_data_memory(logic [ADDR_WIDTH-1:0] addr, logic [31:0] value);
        dut.u_data_memory.mem[addr[DMEM_WORD_BITS+1:2]] = value;
    endtask

    function automatic logic [31:0] read_data_memory_word(logic [ADDR_WIDTH-1:0] addr);
        return dut.u_data_memory.mem[addr[DMEM_WORD_BITS+1:2]];
    endfunction

    //==========================================================================
    // Reset
    //==========================================================================

    task automatic reset_dut();
        rst           = 1'b1;
        pc_enable     = 1'b1;
        reg_write     = 1'b0;
        alu_src       = 1'b0;
        alu_op        = ALU_OP_ADD;
        mem_read      = 1'b0;
        mem_write     = 1'b0;
        access_size   = WORD_ACCESS;
        load_unsigned = 1'b0;
        wb_sel        = WB_ALU;
        pc_src        = PC_SEQ;
        branch_type   = BR_EQ;
        repeat (2) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
    endtask

    //==========================================================================
    // Concurrent Assertion
    //==========================================================================
    // Everything else in this DUT is purely combinational (like
    // main_control), so there's only one genuinely temporal property worth
    // an assert property here: pc_enable_i is a real register-gating
    // signal, and this is the only place it gets exercised at all.
    //==========================================================================

    ASSERT_PC_ENABLE_GATING: assert property (
        @(posedge clk) disable iff (rst)
        (!pc_enable) |-> $stable(dut.pc)
    ) else $error("pc changed while pc_enable_i was deasserted");

    //==========================================================================
    // run_transaction()
    //   Applies one instruction and checks next_pc, the eventual register
    //   write, and the eventual memory write against the golden model.
    //   Assumes dut.pc is already forced to TEST_PC (done once, in the
    //   Initial Block, since it never needs to change between calls).
    //==========================================================================

    task automatic run_transaction(dp_transaction tr);

        control_signals_t ctrl;
        logic [31:0] instr;
        logic [31:0] rs1_val, rs2_val, imm;
        logic [31:0] eff_addr;
        logic [31:0] alu_operand_a, alu_operand_b, alu_result;
        logic [31:0] next_pc_expected;
        logic [31:0] mem_word_before, wb_data_expected;
        logic [31:0] rd_before;

        bit match;

        instr = tr.build_instruction();
        ctrl  = decode_control(instr);
        cov_opcode = tr.opcode;

        load_instruction(TEST_PC, instr);

        rs1_val = (tr.rs1_addr == 5'd0) ? 32'b0 : tr.rs1_val;
        rs2_val = (tr.rs2_addr == 5'd0) ? 32'b0 : tr.rs2_val;
        preload_register(tr.rs1_addr, tr.rs1_val);
        preload_register(tr.rs2_addr, tr.rs2_val);

        imm      = compute_immediate(instr);
        eff_addr = rs1_val + imm;

        if (tr.opcode == OPCODE_LOAD || tr.opcode == OPCODE_STORE)
            preload_data_memory(eff_addr, tr.mem_preload_val);

        mem_word_before = read_data_memory_word(eff_addr);
        rd_before        = read_register(tr.rd_addr);

        reg_write     = ctrl.reg_write;
        alu_src       = ctrl.alu_src;
        alu_op        = ctrl.alu_op;
        mem_read      = ctrl.mem_read;
        mem_write     = ctrl.mem_write;
        access_size   = ctrl.access_size;
        load_unsigned = ctrl.load_unsigned;
        wb_sel        = ctrl.wb_sel;
        pc_src        = ctrl.pc_src;
        branch_type   = ctrl.branch_type;

        #0; // Delta cycle - let the combinational datapath settle

        alu_operand_a = rs1_val;
        alu_operand_b = ctrl.alu_src ? imm : rs2_val;
        alu_result = compute_alu_result(
            alu_operand_a, alu_operand_b, ctrl.alu_op, tr.funct3, tr.funct7
        );

        next_pc_expected = compute_next_pc(TEST_PC, imm, rs1_val, rs2_val, ctrl.pc_src, ctrl.branch_type);
        wb_data_expected = compute_writeback_data(ctrl.wb_sel, alu_result, mem_word_before, TEST_PC, imm);

        // register_file/data_memory write via non-blocking assignment,
        // which settles after control resumes from @(posedge clk) - a
        // small delay is needed before reading any backdoor post-edge
        // state, or you'd see last cycle's value instead of this edge's.
        @(posedge clk);
        #1;

        match = (dut.next_pc === next_pc_expected);

        if (ctrl.reg_write) begin
            logic [31:0] rd_expected;
            rd_expected = (tr.rd_addr == 5'd0) ? 32'b0 : wb_data_expected;
            match &= (read_register(tr.rd_addr) === rd_expected);
        end else begin
            match &= (read_register(tr.rd_addr) === rd_before); // untouched
        end

        if (ctrl.mem_write)
            match &= (read_data_memory_word(eff_addr) === rs2_val);

        cg.sample();

        if (match) begin
            pass_count++;
        end else begin
            $display("FAIL [%0s] instr=%08h  next_pc: exp=%08h act=%08h  wb_exp=%08h",
                       tr.label(), instr, next_pc_expected, dut.next_pc, wb_data_expected);
            fail_count++;
        end

    endtask

    //==========================================================================
    // Directed Tests
    //==========================================================================

    task automatic run_directed_test(dp_transaction tr);
        run_transaction(tr);
        directed_test_count++;
    endtask

    task automatic run_directed_tests();

        dp_transaction tr;

        $display("========================================================");
        $display(" Directed Tests");
        $display("========================================================");

        tr = new(); tr.opcode = OPCODE_RTYPE; tr.funct3 = 3'b000; tr.funct7 = 7'b0;
        tr.rs1_addr = 5'd1; tr.rs2_addr = 5'd2; tr.rd_addr = 5'd3;
        tr.rs1_val = 32'd10; tr.rs2_val = 32'd20;
        run_directed_test(tr); // ADD x3, x1, x2

        tr = new(); tr.opcode = OPCODE_ITYPE; tr.funct3 = 3'b000;
        tr.rs1_addr = 5'd1; tr.rd_addr = 5'd2;
        tr.rs1_val = 32'd5; tr.imm_raw = 32'hFFFF_FFFF;
        run_directed_test(tr); // ADDI x2, x1, -1

        tr = new(); tr.opcode = OPCODE_LOAD; tr.funct3 = F3_LW;
        tr.rs1_addr = 5'd1; tr.rd_addr = 5'd3;
        tr.rs1_val = 32'h0; tr.imm_raw = 32'd8; tr.mem_preload_val = 32'hCAFEF00D;
        run_directed_test(tr); // LW x3, 8(x1)

        tr = new(); tr.opcode = OPCODE_STORE; tr.funct3 = F3_SW;
        tr.rs1_addr = 5'd1; tr.rs2_addr = 5'd2;
        tr.rs1_val = 32'h0; tr.imm_raw = 32'd4; tr.rs2_val = 32'hDEADBEEF;
        run_directed_test(tr); // SW x2, 4(x1)

        tr = new(); tr.opcode = OPCODE_BRANCH; tr.funct3 = F3_BEQ;
        tr.rs1_addr = 5'd1; tr.rs2_addr = 5'd2;
        tr.rs1_val = 32'd42; tr.rs2_val = 32'd42; tr.imm_raw = 32'd16;
        run_directed_test(tr); // BEQ x1, x2, +16 (taken)

        tr = new(); tr.opcode = OPCODE_BRANCH; tr.funct3 = F3_BEQ;
        tr.rs1_addr = 5'd1; tr.rs2_addr = 5'd2;
        tr.rs1_val = 32'd42; tr.rs2_val = 32'd7; tr.imm_raw = 32'd16;
        run_directed_test(tr); // BEQ x1, x2, +16 (not taken)

        tr = new(); tr.opcode = OPCODE_JAL; tr.rd_addr = 5'd1; tr.imm_raw = 32'd32;
        run_directed_test(tr); // JAL x1, +32

        tr = new(); tr.opcode = OPCODE_JALR; tr.funct3 = 3'b000;
        tr.rs1_addr = 5'd2; tr.rd_addr = 5'd1;
        tr.rs1_val = 32'h100; tr.imm_raw = 32'd5;
        run_directed_test(tr); // JALR x1, 5(x2)

        tr = new(); tr.opcode = OPCODE_LUI; tr.rd_addr = 5'd5; tr.imm_raw = 32'h1234;
        run_directed_test(tr); // LUI x5, 0x1234

        tr = new(); tr.opcode = OPCODE_AUIPC; tr.rd_addr = 5'd6; tr.imm_raw = 32'h1000;
        run_directed_test(tr); // AUIPC x6, 0x1000

        tr = new(); tr.opcode = OPCODE_RTYPE; tr.funct3 = 3'b000; tr.funct7 = 7'b0;
        tr.rs1_addr = 5'd1; tr.rs2_addr = 5'd2; tr.rd_addr = 5'd0;
        tr.rs1_val = 32'hFFFF_FFFF; tr.rs2_val = 32'hFFFF_FFFF;
        run_directed_test(tr); // ADD x0, x1, x2 - x0 must stay 0

    endtask

    //==========================================================================
    // Random Tests
    //==========================================================================

    task automatic run_random_tests();

        dp_transaction tr;

        $display("========================================================");
        $display(" Random Tests (%0d)", NUM_RANDOM_TESTS);
        $display("========================================================");

        repeat (NUM_RANDOM_TESTS) begin
            tr = new();
            assert (tr.randomize());

            // LOAD/STORE effective address kept aligned and in range -
            // simpler to fix up procedurally than to constrain rs1_val+imm
            // directly (that ties two rand fields together, which is much
            // more expensive for the solver than it's worth here).
            if (tr.opcode == OPCODE_LOAD || tr.opcode == OPCODE_STORE) begin
                tr.rs1_val = 32'h0;
                tr.imm_raw = 32'($urandom_range(0, 511)) << 2;
            end

            run_transaction(tr);
            random_test_count++;
        end

    endtask

    //==========================================================================
    // Coverage / Summary Report
    //==========================================================================

    task automatic print_summary();
        $display("==========================================================");
        $display(" Coverage / Summary Report");
        $display("==========================================================");
        $display(" Directed Tests Run  : %0d", directed_test_count);
        $display(" Random Tests Run    : %0d", random_test_count);
        $display(" Opcode Coverage     : %0.2f%%", cg.get_coverage());
        $display("----------------------------------------------------------");
        $display(" Pass                : %0d", pass_count);
        $display(" Fail                : %0d", fail_count);
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
        $display(" RV32I Datapath Testbench");
        $display("==========================================================");

        reset_dut();

        force dut.pc = TEST_PC; // Fixed test address for every transaction

        run_directed_tests();
        run_random_tests();

        release dut.pc;

        print_summary();

        $finish;

    end

endmodule
