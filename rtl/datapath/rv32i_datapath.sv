//==============================================================================
// rv32i_datapath.sv
//==============================================================================
//
// Top-Level Datapath for a parameterized RV32I single-cycle processor.
//
// Instantiates every datapath module and wires them together. This module
// performs NO instruction decoding of its own - every control decision is
// taken as an input (driven by main_control at the processor level). The
// only "decisions" made here are pure field extraction (bit slices) and
// data routing between the already-verified reference modules.
//
//==============================================================================

import rv32i_pkg::*;
import alu_pkg::*;

module rv32i_datapath #(

    parameter int    XLEN       = 32,
    parameter int    ADDR_WIDTH = XLEN,
    parameter int    NUM_REGS   = 32,

    parameter int    IMEM_DEPTH = 256,
    parameter string IMEM_FILE  = "program.hex",
    parameter int    DMEM_DEPTH = 1024,

    parameter logic [ADDR_WIDTH-1:0] RESET_ADDR = '0

)(

    //==========================================================================
    // Clock / Reset
    //==========================================================================

    input  logic clk_i,
    input  logic rst_i,

    //==========================================================================
    // PC Enable
    //==========================================================================
    // Not sourced from Main Control (main_control has no stall/debug output
    // today). Driven by the processor wrapper - see rv32i_processor.sv.
    //==========================================================================

    input  logic pc_enable_i,

    //==========================================================================
    // Control Signals (from Main Control Unit)
    //==========================================================================

    input  logic             reg_write_i,

    input  logic             alu_src_i,
    input  alu_ctrl_sel_t    alu_op_i,

    input  logic             mem_read_i,
    input  logic             mem_write_i,
    input  mem_access_size_t access_size_i,
    input  logic             load_unsigned_i,

    input  wb_sel_t          wb_sel_i,

    input  pc_src_t          pc_src_i,
    input  branch_type_t     branch_type_i,

    //==========================================================================
    // Status Output (to Main Control Unit)
    //==========================================================================

    output logic [XLEN-1:0]  instruction_o

);

    //==========================================================================
    // Internal Signals
    //==========================================================================

    // Program Counter / Fetch
    logic [ADDR_WIDTH-1:0] pc;
    logic [ADDR_WIDTH-1:0] next_pc;
    logic [XLEN-1:0]       instruction;

    // Instruction Fields
    logic [6:0] opcode;
    logic [4:0] rs1_addr;
    logic [4:0] rs2_addr;
    logic [4:0] rd_addr;
    logic [2:0] funct3;
    logic [6:0] funct7;

    // Register File
    logic [XLEN-1:0] rs1_data;
    logic [XLEN-1:0] rs2_data;

    // Immediate
    logic [XLEN-1:0] imm;

    // Address Generation
    logic [ADDR_WIDTH-1:0] pc_plus4;
    logic [ADDR_WIDTH-1:0] pc_plus_imm;
    logic [ADDR_WIDTH-1:0] rs1_plus_imm;

    // ALU
    logic [XLEN-1:0] alu_operand_a;
    logic [XLEN-1:0] alu_operand_b;
    alu_op_t         alu_op_decoded;
    logic [XLEN-1:0] alu_result;
    logic            alu_zero_flag;   // Unused - branch resolution uses branch_comparator, not this flag

    // Branch Comparator
    logic branch_eq;
    logic branch_lt;
    logic branch_ltu;

    // Data Memory
    logic [XLEN-1:0] memory_read_data;

    // Writeback
    logic [XLEN-1:0] writeback_data;

    //==========================================================================
    // Instruction Field Extraction
    //==========================================================================
    // Pure field extraction only - no opcode/funct3/funct7-based decisions
    // are made anywhere in this module.
    //==========================================================================

    assign opcode   = instruction[6:0];
    assign rd_addr  = instruction[11:7];
    assign funct3   = instruction[14:12];
    assign rs1_addr = instruction[19:15];
    assign rs2_addr = instruction[24:20];
    assign funct7   = instruction[31:25];

    assign instruction_o = instruction;

    //==========================================================================
    // Module Instantiation
    //==========================================================================

    //--------------------------------------------------------------------------
    // Program Counter
    //--------------------------------------------------------------------------

    program_counter #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .RESET_ADDR (RESET_ADDR)
    ) u_program_counter (
        .clk_i       (clk_i),
        .rst_i       (rst_i),
        .pc_enable_i (pc_enable_i), // Driven by the processor wrapper
        .next_pc_i   (next_pc),
        .pc_o        (pc)
    );

    //--------------------------------------------------------------------------
    // Instruction Memory
    //--------------------------------------------------------------------------
    // INSTR_ADDR_WIDTH is the full processor address width (ADDR_WIDTH),
    // not $clog2(IMEM_DEPTH). instruction_memory.sv derives its own internal
    // word-index width from DEPTH and slices it out of pc_i itself
    // (pc_i[MEM_ADDR_WIDTH+1:2]); it expects the full byte address on
    // pc_i, the same pattern data_memory.sv uses for addr_i.
    //--------------------------------------------------------------------------

    instruction_memory #(
        .DEPTH            (IMEM_DEPTH),
        .INSTR_ADDR_WIDTH (ADDR_WIDTH),
        .INSTR_WIDTH      (XLEN),
        .MEM_FILE         (IMEM_FILE)
    ) u_instruction_memory (
        .pc_i          (pc),
        .instruction_o (instruction)
    );

    //--------------------------------------------------------------------------
    // Register File
    //--------------------------------------------------------------------------

    register_file #(
        .DATA_WIDTH (XLEN),
        .NUM_REGS   (NUM_REGS)
    ) u_register_file (
        .clk          (clk_i),
        .rst          (rst_i),
        .read_addr_1  (rs1_addr),
        .read_addr_2  (rs2_addr),
        .write_enable (reg_write_i),
        .write_addr   (rd_addr),
        .write_data   (writeback_data),
        .read_data_1  (rs1_data),
        .read_data_2  (rs2_data)
    );

    //--------------------------------------------------------------------------
    // Immediate Generator
    //--------------------------------------------------------------------------

    immediate_generator #(
        .XLEN (XLEN)
    ) u_immediate_generator (
        .instruction_i (instruction),
        .immediate_o   (imm)
    );

    //--------------------------------------------------------------------------
    // ALU Operand A
    //--------------------------------------------------------------------------
    // Operand A is driven directly by rs1_data in this implementation.
    // Future architectures (pipeline, AUIPC optimization, etc.) may
    // introduce a mux here.
    //--------------------------------------------------------------------------

    assign alu_operand_a = rs1_data;

    //--------------------------------------------------------------------------
    // ALU Operand MUX (operand B: register vs. immediate)
    //--------------------------------------------------------------------------

    alu_operand_mux #(
        .XLEN (XLEN)
    ) u_alu_operand_mux (
        .rs2_data_i  (rs2_data),
        .imm_i       (imm),
        .alu_src_i   (alu_src_i),
        .operand_b_o (alu_operand_b)
    );

    //--------------------------------------------------------------------------
    // ALU Control (2-bit selector + funct3/funct7 -> concrete ALU operation)
    //--------------------------------------------------------------------------

    alu_control u_alu_control (
        .alu_op_i (alu_op_i),
        .funct3_i (funct3),
        .funct7_i (funct7),
        .alu_op_o (alu_op_decoded)
    );

    //--------------------------------------------------------------------------
    // ALU
    //--------------------------------------------------------------------------

    alu #(
        .DATA_WIDTH (XLEN)
    ) u_alu (
        .operand_a (alu_operand_a),
        .operand_b (alu_operand_b),
        .alu_op    (alu_op_decoded),
        .result    (alu_result),
        .zero_flag (alu_zero_flag)
    );

    //--------------------------------------------------------------------------
    // Branch Comparator
    //--------------------------------------------------------------------------

    branch_comparator #(
        .DATA_WIDTH (XLEN)
    ) u_branch_comparator (
        .operand_a_i (rs1_data),
        .operand_b_i (rs2_data),
        .eq_o        (branch_eq),
        .lt_o        (branch_lt),
        .ltu_o       (branch_ltu)
    );

    //--------------------------------------------------------------------------
    // Address Generator
    //--------------------------------------------------------------------------

    address_generator #(
        .XLEN       (XLEN),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_address_generator (
        .pc_i           (pc),
        .imm_i          (imm),
        .rs1_data_i     (rs1_data),
        .pc_plus4_o     (pc_plus4),
        .pc_plus_imm_o  (pc_plus_imm),
        .rs1_plus_imm_o (rs1_plus_imm)
    );

    //--------------------------------------------------------------------------
    // Next PC Logic
    //--------------------------------------------------------------------------

    next_pc_logic #(
        .XLEN       (XLEN),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_next_pc_logic (
        .pc_plus4_i     (pc_plus4),
        .pc_plus_imm_i  (pc_plus_imm),
        .rs1_plus_imm_i (rs1_plus_imm),
        .eq_i           (branch_eq),
        .lt_i           (branch_lt),
        .ltu_i          (branch_ltu),
        .pc_src_i       (pc_src_i),
        .branch_type_i  (branch_type_i),
        .next_pc_o      (next_pc)
    );

    //--------------------------------------------------------------------------
    // Data Memory
    //--------------------------------------------------------------------------

    data_memory #(
        .XLEN      (XLEN),
        .MEM_DEPTH (DMEM_DEPTH)
    ) u_data_memory (
        .clk_i           (clk_i),
        .mem_read_i      (mem_read_i),
        .mem_write_i     (mem_write_i),
        .addr_i          (alu_result),
        .write_data_i    (rs2_data),
        .access_size_i   (access_size_i),
        .load_unsigned_i (load_unsigned_i),
        .read_data_o     (memory_read_data)
    );

    //--------------------------------------------------------------------------
    // Writeback MUX
    //--------------------------------------------------------------------------

    writeback_mux #(
        .XLEN (XLEN)
    ) u_writeback_mux (
        .alu_result_i  (alu_result),
        .mem_data_i    (memory_read_data),
        .pc_plus4_i    (pc_plus4),
        .pc_plus_imm_i (pc_plus_imm),
        .imm_i         (imm),
        .wb_sel_i      (wb_sel_i),
        .wb_data_o     (writeback_data)
    );

endmodule
