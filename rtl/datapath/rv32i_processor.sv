//==============================================================================
// rv32i_processor.sv
//==============================================================================
//
// Final Single-Cycle RV32I Processor.
//
// Connects the Main Control Unit to the Top-Level Datapath:
//
//     instruction -> main_control -> control signals -> datapath
//
// This module contains no datapath logic of its own - it is purely a
// structural connection between the two child modules.
//
//==============================================================================

import rv32i_pkg::*;

module rv32i_processor #(

    parameter int    XLEN       = 32,
    parameter int    ADDR_WIDTH = XLEN,
    parameter int    NUM_REGS   = 32,

    parameter int    IMEM_DEPTH = 256,
    parameter string IMEM_FILE  = "program.hex",
    parameter int    DMEM_DEPTH = 1024,

    parameter logic [ADDR_WIDTH-1:0] RESET_ADDR = '0

)(

    //==========================================================================
    // Processor-Level Ports
    //==========================================================================

    input  logic clk_i,
    input  logic rst_i

);

    //==========================================================================
    // Internal Signals
    //==========================================================================

    // Instruction (Datapath -> Main Control)
    logic [XLEN-1:0] instruction;

    // Control Signals (Main Control -> Datapath)
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
    // Module Instantiation
    //==========================================================================

    //--------------------------------------------------------------------------
    // Main Control Unit
    //--------------------------------------------------------------------------

    main_control u_main_control (

        .instruction_i   (instruction),

        .reg_write_o     (reg_write),

        .alu_src_o       (alu_src),
        .alu_op_o        (alu_op),

        .mem_read_o      (mem_read),
        .mem_write_o     (mem_write),
        .access_size_o   (access_size),
        .load_unsigned_o (load_unsigned),

        .wb_sel_o        (wb_sel),

        .pc_src_o        (pc_src),
        .branch_type_o   (branch_type)

    );

    //--------------------------------------------------------------------------
    // Top-Level Datapath
    //--------------------------------------------------------------------------

    rv32i_datapath #(

        .XLEN       (XLEN),
        .ADDR_WIDTH (ADDR_WIDTH),
        .NUM_REGS   (NUM_REGS),

        .IMEM_DEPTH (IMEM_DEPTH),
        .IMEM_FILE  (IMEM_FILE),
        .DMEM_DEPTH (DMEM_DEPTH),

        .RESET_ADDR (RESET_ADDR)

    ) u_rv32i_datapath (

        .clk_i (clk_i),
        .rst_i (rst_i),

        // No stall/debug/halt logic exists yet - always enabled.
        // Future pipeline/wait-state/debug-halt logic only needs to change
        // this one connection.
        .pc_enable_i (1'b1),

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

        .instruction_o   (instruction)

    );

endmodule
