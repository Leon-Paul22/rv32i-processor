`timescale 1ns/1ps

typedef enum logic [1:0] {
    PC_SEQ,
    PC_BRANCH,
    PC_JAL,
    PC_JALR
} pc_src_t;

typedef enum logic [2:0] {
    BR_EQ,
    BR_NE,
    BR_LT,
    BR_GE,
    BR_LTU,
    BR_GEU
} branch_type_t;

module tb_next_pc;

parameter int XLEN = 32;
parameter int ADDR_WIDTH = XLEN;
parameter int NUM_RANDOM_TESTS = 100;

// -----------------------------------------------------------------------------
// DUT Signals
// -----------------------------------------------------------------------------
logic [ADDR_WIDTH-1:0] pc_plus4_i;
logic [ADDR_WIDTH-1:0] pc_plus_imm_i;
logic [ADDR_WIDTH-1:0] rs1_plus_imm_i;

logic eq_i;
logic lt_i;
logic ltu_i;

pc_src_t      pc_src_i;
branch_type_t branch_type_i;

logic [ADDR_WIDTH-1:0] next_pc_o;

logic branch_taken;

int pass_count = 0;
int fail_count = 0;

// -----------------------------------------------------------------------------
// DUT
// -----------------------------------------------------------------------------
next_pc #(
    .XLEN(XLEN),
    .ADDR_WIDTH(ADDR_WIDTH)
) dut (
    .pc_plus4_i(pc_plus4_i),
    .pc_plus_imm_i(pc_plus_imm_i),
    .rs1_plus_imm_i(rs1_plus_imm_i),
    .eq_i(eq_i),
    .lt_i(lt_i),
    .ltu_i(ltu_i),
    .pc_src_i(pc_src_i),
    .branch_type_i(branch_type_i),
    .next_pc_o(next_pc_o)
);

// -----------------------------------------------------------------------------
// Functional Coverage
// -----------------------------------------------------------------------------
covergroup cg_next_pc;

    cp_pc_src : coverpoint pc_src_i {
        bins seq    = {PC_SEQ};
        bins branch = {PC_BRANCH};
        bins jal    = {PC_JAL};
        bins jalr   = {PC_JALR};
    }

    cp_branch_type : coverpoint branch_type_i
        iff (pc_src_i == PC_BRANCH)
    {
        bins beq  = {BR_EQ};
        bins bne  = {BR_NE};
        bins blt  = {BR_LT};
        bins bge  = {BR_GE};
        bins bltu = {BR_LTU};
        bins bgeu = {BR_GEU};
    }

    cp_branch_taken : coverpoint branch_taken
        iff (pc_src_i == PC_BRANCH)
    {
        bins taken     = {1'b1};
        bins not_taken = {1'b0};
    }

    cross cp_branch_type, cp_branch_taken;

endgroup

cg_next_pc coverage;

// -----------------------------------------------------------------------------
// Independent Reference Model
// -----------------------------------------------------------------------------
function automatic logic [ADDR_WIDTH-1:0] expected_next_pc(
    input logic [ADDR_WIDTH-1:0] pc4,
    input logic [ADDR_WIDTH-1:0] pcimm,
    input logic [ADDR_WIDTH-1:0] rs1imm,
    input logic eq,
    input logic lt,
    input logic ltu,
    input pc_src_t src,
    input branch_type_t br
);
begin
    expected_next_pc = pc4;

    if (src == PC_JAL)
        expected_next_pc = pcimm;

    else if (src == PC_JALR)
        expected_next_pc = rs1imm;

    else if (src == PC_BRANCH) begin
        if      ((br == BR_EQ ) &&  eq ) expected_next_pc = pcimm;
        else if ((br == BR_NE ) && !eq ) expected_next_pc = pcimm;
        else if ((br == BR_LT ) &&  lt ) expected_next_pc = pcimm;
        else if ((br == BR_GE ) && !lt ) expected_next_pc = pcimm;
        else if ((br == BR_LTU) &&  ltu) expected_next_pc = pcimm;
        else if ((br == BR_GEU) && !ltu) expected_next_pc = pcimm;
        else                             expected_next_pc = pc4;
    end
end
endfunction

task automatic check_outputs;
    logic [ADDR_WIDTH-1:0] expected;
begin

    branch_taken = 1'b0;
    if (pc_src_i == PC_BRANCH) begin
        case (branch_type_i)
            BR_EQ :  branch_taken = eq_i;
            BR_NE :  branch_taken = !eq_i;
            BR_LT :  branch_taken = lt_i;
            BR_GE :  branch_taken = !lt_i;
            BR_LTU:  branch_taken = ltu_i;
            BR_GEU:  branch_taken = !ltu_i;
        endcase
    end

    expected = expected_next_pc(
        pc_plus4_i,
        pc_plus_imm_i,
        rs1_plus_imm_i,
        eq_i,
        lt_i,
        ltu_i,
        pc_src_i,
        branch_type_i
    );

    assert(next_pc_o == expected)
    else begin
        $error("NEXT_PC mismatch Exp=%h Got=%h", expected, next_pc_o);
        fail_count++;
    end

    if (next_pc_o == expected)
        pass_count++;

    coverage.sample();

end
endtask

task automatic apply_inputs(
    input logic [ADDR_WIDTH-1:0] pc4,
    input logic [ADDR_WIDTH-1:0] pcimm,
    input logic [ADDR_WIDTH-1:0] rs1imm,
    input logic eq,
    input logic lt,
    input logic ltu,
    input pc_src_t src,
    input branch_type_t br
);
begin
    pc_plus4_i     = pc4;
    pc_plus_imm_i  = pcimm;
    rs1_plus_imm_i = rs1imm;
    eq_i           = eq;
    lt_i           = lt;
    ltu_i          = ltu;
    pc_src_i       = src;
    branch_type_i  = br;

    #1;
    check_outputs();
end
endtask

task automatic run_directed_tests;
begin
    apply_inputs(32'h4,32'h100,32'h200,0,0,0,PC_SEQ,BR_EQ);

    apply_inputs(32'h4,32'h100,32'h200,1,0,0,PC_BRANCH,BR_EQ);
    apply_inputs(32'h4,32'h100,32'h200,0,0,0,PC_BRANCH,BR_EQ);

    apply_inputs(32'h4,32'h100,32'h200,0,1,0,PC_BRANCH,BR_LT);
    apply_inputs(32'h4,32'h100,32'h200,0,0,0,PC_BRANCH,BR_LT);

    apply_inputs(32'h4,32'h100,32'h200,0,0,1,PC_BRANCH,BR_LTU);
    apply_inputs(32'h4,32'h100,32'h200,0,0,0,PC_BRANCH,BR_LTU);

    apply_inputs(32'h4,32'h100,32'h200,0,0,0,PC_JAL,BR_EQ);
    apply_inputs(32'h4,32'h100,32'h200,0,0,0,PC_JALR,BR_EQ);
end
endtask

task automatic run_random_tests;
int i;
begin
    for(i=0;i<NUM_RANDOM_TESTS;i++) begin
        apply_inputs(
            $urandom,
            $urandom,
            $urandom,
            $urandom_range(0,1),
            $urandom_range(0,1),
            $urandom_range(0,1),
            pc_src_t'($urandom_range(0,3)),
            branch_type_t'($urandom_range(0,5))
        );
    end
end
endtask

initial begin
    coverage = new();

    run_directed_tests();
    run_random_tests();

    $display("--------------------------------");
    $display("Pass = %0d", pass_count);
    $display("Fail = %0d", fail_count);
    $display("--------------------------------");

    $finish;
end

endmodule
