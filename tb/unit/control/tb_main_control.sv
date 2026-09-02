import rv32i_pkg::*;

class control_transaction;
    rand logic [6:0] opcode;
    rand logic [2:0] funct3;

    logic exp_reg_write;
    logic exp_alu_src;
    alu_ctrl_sel_t exp_alu_op;
    logic exp_mem_read;
    logic exp_mem_write;
    mem_access_size_t exp_access_size;
    logic exp_load_unsigned;
    wb_sel_t exp_wb_sel;
    pc_src_t exp_pc_src;
    branch_type_t exp_branch_type;

function void print(
    input logic             reg_write,
    input logic             alu_src,
    input alu_ctrl_sel_t    alu_op,
    input logic             mem_read,
    input logic             mem_write,
    input mem_access_size_t access_size,
    input logic             load_unsigned,
    input wb_sel_t          wb_sel,
    input pc_src_t          pc_src,
    input branch_type_t     branch_type
);

    $display("Main Control Unit Transaction Failure");
    $display("----------------------------------------");

    $display("Stimulus");
    $display("----------------------------------------");
    $display("opcode          : %07b", opcode);
    $display("funct3          : %03b", funct3);

    $display("\nExpected vs Actual");
    $display("----------------------------------------");
    $display("reg_write       : %0b\t|\t%0b", exp_reg_write,      reg_write);
    $display("alu_src         : %0b\t|\t%0b", exp_alu_src,        alu_src);
    $display("alu_op     : %s\t|\t%s",
             exp_alu_op.name(), alu_op.name());
    $display("mem_read        : %0b\t|\t%0b", exp_mem_read,       mem_read);
    $display("mem_write       : %0b\t|\t%0b", exp_mem_write,      mem_write);
    $display("access_size     : %s\t|\t%s",
             exp_access_size.name(), access_size.name());
    $display("load_unsigned   : %0b\t|\t%0b",
             exp_load_unsigned, load_unsigned);
    $display("wb_sel          : %s\t|\t%s",
             exp_wb_sel.name(), wb_sel.name());
    $display("pc_src          : %s\t|\t%s",
             exp_pc_src.name(), pc_src.name());
    $display("branch_type     : %s\t|\t%s",
             exp_branch_type.name(), branch_type.name());

    $display("----------------------------------------");

endfunction

constraint opcode_c {
    opcode inside {
        OPCODE_RTYPE,
        OPCODE_ITYPE,
        OPCODE_LOAD,
        OPCODE_STORE,
        OPCODE_BRANCH,
        OPCODE_JALR,
        OPCODE_JAL,
        OPCODE_LUI,
        OPCODE_AUIPC
    };
}

constraint load_c{
    if (opcode == OPCODE_LOAD)
        funct3 inside {
            F3_LB, 
            F3_LBU, 
            F3_LH, 
            F3_LHU, 
            F3_LW
    };
}

constraint store_c{
    if (opcode == OPCODE_STORE)
        funct3 inside {
            F3_SB,
            F3_SH,
            F3_SW
        };
}

constraint branch_c{
    if (opcode == OPCODE_BRANCH)
        funct3 inside {
            F3_BEQ,
            F3_BNE,
            F3_BLT,
            F3_BGE,
            F3_BLTU,
            F3_BGEU
        };
}

constraint jalr_c{
    if (opcode == OPCODE_JALR)
        funct3 == 3'b000;
}

endclass

//==============================================================================
// Testbench Module
//==============================================================================
//
// Instantiates the Main Control Unit DUT and drives it using the
// control_transaction class defined above. Functional coverage
// (cg_main_control) is declared as a free-standing covergroup below,
// rather than embedded in the class.
//
// Sections 6-10 (Immediate Assertions, Concurrent Assertions, Directed
// Tests, Random Tests, Coverage Summary) are intentionally left as
// TODO stubs - see Main_Control_Unit_Testbench_Specification.docx.
//
//==============================================================================

`timescale 1ns/1ps

module tb_main_control;

    //==========================================================================
    // Parameters
    //==========================================================================

    parameter int NUM_RANDOM_TESTS = 1000;

    //==========================================================================
    // DUT Signals
    //==========================================================================

    // Inputs

    logic [31:0] instruction;

    // Outputs

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

    //==========================================================================
    // Functional Coverage
    //==========================================================================
    
    logic [6:0] opcode;
    logic [2:0] funct3;

    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];

    covergroup cg_main_control;

        cp_opcode : coverpoint opcode {
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

        cp_funct3_load : coverpoint funct3 iff (opcode == OPCODE_LOAD) {
            bins lb  = {F3_LB};
            bins lh  = {F3_LH};
            bins lw  = {F3_LW};
            bins lbu = {F3_LBU};
            bins lhu = {F3_LHU};
        }

        cp_funct3_store : coverpoint funct3 iff (opcode == OPCODE_STORE) {
            bins sb = {F3_SB};
            bins sh = {F3_SH};
            bins sw = {F3_SW};
        }

        cp_funct3_branch : coverpoint funct3 iff (opcode == OPCODE_BRANCH) {
            bins beq  = {F3_BEQ};
            bins bne  = {F3_BNE};
            bins blt  = {F3_BLT};
            bins bge  = {F3_BGE};
            bins bltu = {F3_BLTU};
            bins bgeu = {F3_BGEU};
        }

        cross cp_opcode, cp_funct3_load;
        cross cp_opcode, cp_funct3_store;
        cross cp_opcode, cp_funct3_branch;

    endgroup

    cg_main_control cg = new();

    //==========================================================================
    // Test Bookkeeping
    //==========================================================================
  
    int unsigned pass_count          = 0;
    int unsigned fail_count          = 0;
    int unsigned directed_test_count = 0;
    int unsigned random_test_count   = 0;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================

    main_control dut (

        .instruction_i    (instruction),

        .reg_write_o      (reg_write),

        .alu_src_o        (alu_src),
        .alu_op_o         (alu_op),

        .mem_read_o       (mem_read),
        .mem_write_o      (mem_write),
        .access_size_o    (access_size),
        .load_unsigned_o  (load_unsigned),

        .wb_sel_o         (wb_sel),

        .pc_src_o         (pc_src),
        .branch_type_o    (branch_type)

    );

    //==========================================================================
    // Golden Reference Model
    //==========================================================================
    // Computes expected outputs only - fills txn.exp_* fields.
    //
    // This is deliberately re-derived from the RV32I control-signal
    // specification rather than copied from main_control.sv: if it just
    // mirrored the RTL's case-statement structure, a decode bug in the DUT
    // would be reproduced here too, and compare_outputs() would never catch
    // it. Keeping the two implementations independent is what makes this a
    // real golden reference model instead of a checksum of the RTL.
    //==========================================================================

    function automatic void golden_model(control_transaction txn);

        //----------------------------------------------------------------------
        // Safe Defaults
        //----------------------------------------------------------------------

        txn.exp_reg_write     = 1'b0;

        txn.exp_alu_src       = 1'b0;
        txn.exp_alu_op        = ALU_OP_ADD;

        txn.exp_mem_read      = 1'b0;
        txn.exp_mem_write     = 1'b0;
        txn.exp_access_size   = WORD_ACCESS;
        txn.exp_load_unsigned = 1'b0;

        txn.exp_wb_sel        = WB_ALU;

        txn.exp_pc_src        = PC_SEQ;
        txn.exp_branch_type   = BR_EQ;

        //----------------------------------------------------------------------
        // Opcode Decode
        //----------------------------------------------------------------------

        unique case (txn.opcode)

            //==================================================================
            // R-Type
            //==================================================================

            OPCODE_RTYPE: begin
                txn.exp_reg_write = 1'b1;
                txn.exp_alu_src   = 1'b0;
                txn.exp_alu_op    = ALU_OP_RTYPE;
                txn.exp_wb_sel    = WB_ALU;
            end

            //==================================================================
            // I-Type ALU
            //==================================================================

            OPCODE_ITYPE: begin
                txn.exp_reg_write = 1'b1;
                txn.exp_alu_src   = 1'b1;
                txn.exp_alu_op    = ALU_OP_ITYPE;
                txn.exp_wb_sel    = WB_ALU;
            end

            //==================================================================
            // LOAD
            //==================================================================

            OPCODE_LOAD: begin
                txn.exp_reg_write = 1'b1;
                txn.exp_alu_src   = 1'b1;
                txn.exp_alu_op    = ALU_OP_ADD;
                txn.exp_mem_read  = 1'b1;
                txn.exp_wb_sel    = WB_MEM;

                unique case (txn.funct3)

                    F3_LB: begin
                        txn.exp_access_size   = BYTE_ACCESS;
                        txn.exp_load_unsigned = 1'b0;
                    end

                    F3_LH: begin
                        txn.exp_access_size   = HALFWORD_ACCESS;
                        txn.exp_load_unsigned = 1'b0;
                    end

                    F3_LW: begin
                        txn.exp_access_size   = WORD_ACCESS;
                        txn.exp_load_unsigned = 1'b0;
                    end

                    F3_LBU: begin
                        txn.exp_access_size   = BYTE_ACCESS;
                        txn.exp_load_unsigned = 1'b1;
                    end

                    F3_LHU: begin
                        txn.exp_access_size   = HALFWORD_ACCESS;
                        txn.exp_load_unsigned = 1'b1;
                    end

                    default: begin
                        // Unreachable under load_c
                    end

                endcase

            end

            //==================================================================
            // STORE
            //==================================================================

            OPCODE_STORE: begin
                txn.exp_alu_src   = 1'b1;
                txn.exp_alu_op    = ALU_OP_ADD;
                txn.exp_mem_write = 1'b1;

                unique case (txn.funct3)

                    F3_SB: txn.exp_access_size = BYTE_ACCESS;

                    F3_SH: txn.exp_access_size = HALFWORD_ACCESS;

                    F3_SW: txn.exp_access_size = WORD_ACCESS;

                    default: begin
                        // Unreachable under store_c
                    end

                endcase

            end

            //==================================================================
            // BRANCH
            //==================================================================

            OPCODE_BRANCH: begin
                txn.exp_alu_op = ALU_OP_BRANCH;
                txn.exp_pc_src = PC_BRANCH;

                unique case (txn.funct3)

                    F3_BEQ  : txn.exp_branch_type = BR_EQ;

                    F3_BNE  : txn.exp_branch_type = BR_NE;

                    F3_BLT  : txn.exp_branch_type = BR_LT;

                    F3_BGE  : txn.exp_branch_type = BR_GE;

                    F3_BLTU : txn.exp_branch_type = BR_LTU;

                    F3_BGEU : txn.exp_branch_type = BR_GEU;

                    default : begin
                        // Unreachable under branch_c
                    end

                endcase

            end

            //==================================================================
            // JAL
            //==================================================================

            OPCODE_JAL: begin
                txn.exp_reg_write = 1'b1;
                txn.exp_wb_sel    = WB_PC4;
                txn.exp_pc_src    = PC_JAL;
            end

            //==================================================================
            // JALR
            //==================================================================

            OPCODE_JALR: begin
                txn.exp_reg_write = 1'b1;
                txn.exp_wb_sel    = WB_PC4;
                txn.exp_pc_src    = PC_JALR;
            end

            //==================================================================
            // LUI
            //==================================================================

            OPCODE_LUI: begin
                txn.exp_reg_write = 1'b1;
                txn.exp_wb_sel    = WB_IMM;
            end

            //==================================================================
            // AUIPC
            //==================================================================

            OPCODE_AUIPC: begin
                txn.exp_reg_write = 1'b1;
                txn.exp_wb_sel    = WB_AUIPC;
            end

            default: begin
                // Illegal opcode - safe defaults hold.
                // Flagged as an illegal situation in Section 6.
            end

        endcase

    endfunction

    //==========================================================================
    // Helper Tasks
    //==========================================================================

    task automatic apply_transaction(control_transaction txn);

        instruction        = '0;
        instruction[6:0]   = txn.opcode;
        instruction[14:12] = txn.funct3;

        #0; // Delta cycle - let the combinational decoder settle

    endtask

    //--------------------------------------------------------------------------
    // compare_outputs()
    //   Compares DUT outputs against the golden model's expected outputs.
    //   Uses === rather than == so an unresolved X/Z on any control signal
    //   is caught as a mismatch instead of silently propagating.
    //--------------------------------------------------------------------------

    function automatic bit compare_outputs(control_transaction txn);

        bit match;

        match = (reg_write     === txn.exp_reg_write)     &&
                (alu_src       === txn.exp_alu_src)       &&
                (alu_op        === txn.exp_alu_op)        &&
                (mem_read      === txn.exp_mem_read)      &&
                (mem_write     === txn.exp_mem_write)     &&
                (access_size   === txn.exp_access_size)   &&
                (load_unsigned === txn.exp_load_unsigned) &&
                (wb_sel        === txn.exp_wb_sel)        &&
                (pc_src        === txn.exp_pc_src)        &&
                (branch_type   === txn.exp_branch_type);

        return match;

    endfunction

    //--------------------------------------------------------------------------
    // print_failure()
    //   Reports stimulus plus expected-vs-actual outputs. Intended to be
    //   called only when compare_outputs() returns 0.
    //--------------------------------------------------------------------------

    task automatic print_failure(control_transaction txn);

        txn.print(
            .reg_write     (reg_write),
            .alu_src       (alu_src),
            .alu_op        (alu_op),
            .mem_read      (mem_read),
            .mem_write     (mem_write),
            .access_size   (access_size),
            .load_unsigned (load_unsigned),
            .wb_sel        (wb_sel),
            .pc_src        (pc_src),
            .branch_type   (branch_type)
        );

    endtask

    //==========================================================================
    // Immediate Assertions
    //==========================================================================
   
    task automatic check_randomize(control_transaction tr);
        assert (tr.randomize());
    endtask

    //--------------------------------------------------------------------------
    // check_result()
    //--------------------------------------------------------------------------

    task automatic check_result(control_transaction tr);

        bit match;
        match = compare_outputs(tr);

        assert (match)
            pass_count++;
        else begin
            print_failure(tr);
            fail_count++;
        end

    endtask

    //--------------------------------------------------------------------------
    // check_known_outputs()
    //--------------------------------------------------------------------------

    task automatic check_known_outputs();
        assert (!$isunknown({reg_write, alu_src, alu_op, mem_read,
                              mem_write, access_size, load_unsigned,
                              wb_sel, pc_src, branch_type}))
        else $error("main_control produced an unknown (X/Z) output for a legal instruction");
    endtask

    //==========================================================================
    // Concurrent Assertions
    //==========================================================================
    // Intentionally empty - main_control is purely combinational, no clock,
    // no protocol to express as a property.
    //==========================================================================


    //==========================================================================
    // Directed Tests
    //==========================================================================
    // One directed transaction per instruction class. Fields are assigned
    // directly (not via randomize()) so each scenario is fully deterministic.
    //==========================================================================

    task automatic run_directed_test(
        input logic [6:0] opcode,
        input logic [2:0] funct3,
        input string      label
    );

        control_transaction tr;

        $display("  [Directed] %0s", label);

        tr = new();
        tr.opcode = opcode;
        tr.funct3 = funct3;

        golden_model(tr);
        apply_transaction(tr);
        check_result(tr);
        check_known_outputs();
        cg.sample();

        directed_test_count++;

    endtask

    task automatic run_directed_tests();

        $display("========================================================");
        $display(" Directed Tests");
        $display("========================================================");

        run_directed_test(OPCODE_RTYPE,  3'b000, "R-Type");
        run_directed_test(OPCODE_ITYPE,  3'b000, "I-Type ALU");
        run_directed_test(OPCODE_LOAD,   F3_LW,  "LOAD (LW)");
        run_directed_test(OPCODE_STORE,  F3_SW,  "STORE (SW)");
        run_directed_test(OPCODE_BRANCH, F3_BEQ, "BRANCH (BEQ)");
        run_directed_test(OPCODE_JAL,    3'b000, "JAL");
        run_directed_test(OPCODE_JALR,   3'b000, "JALR");
        run_directed_test(OPCODE_LUI,    3'b000, "LUI");
        run_directed_test(OPCODE_AUIPC,  3'b000, "AUIPC");

    endtask

    //==========================================================================
    // Random Tests
    //==========================================================================

    task automatic run_random_tests();

        control_transaction tr;

        $display("========================================================");
        $display(" Random Tests (%0d)", NUM_RANDOM_TESTS);
        $display("========================================================");

        repeat (NUM_RANDOM_TESTS) begin

            tr = new();

            check_randomize(tr);
            golden_model(tr);
            apply_transaction(tr);
            check_result(tr);
            check_known_outputs();
            cg.sample();

            random_test_count++;

        end

    endtask

    //==========================================================================
    // Initial Block
    //==========================================================================

    initial begin

        $display("==========================================================");
        $display(" Main Control Unit Testbench");
        $display("==========================================================");

        run_directed_tests();
        run_random_tests();
        print_coverage_summary();

        $finish;

    end

    //==========================================================================
    // Coverage Report
    //==========================================================================

    task automatic print_coverage_summary();

        $display("==========================================================");
        $display(" Coverage / Summary Report");
        $display("==========================================================");
        $display(" Directed Tests Run  : %0d", directed_test_count);
        $display(" Random Tests Run    : %0d", random_test_count);
        $display(" Functional Coverage : %0.2f%%", cg.get_coverage());
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

endmodule
