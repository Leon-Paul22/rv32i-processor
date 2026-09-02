//==========================================================================
// main_control.sv
//==========================================================================

`timescale 1ns/1ps

import rv32i_pkg::*;

module main_control(

    //==========================================================================
    // Inputs
    //==========================================================================

    input  logic [31:0] instruction_i,

    //==========================================================================
    // Register File
    //==========================================================================

    output logic             reg_write_o,

    //==========================================================================
    // ALU
    //==========================================================================

    output logic             alu_src_o,
    output alu_ctrl_sel_t    alu_op_o,

    //==========================================================================
    // Data Memory
    //==========================================================================

    output logic             mem_read_o,
    output logic             mem_write_o,
    output mem_access_size_t access_size_o,
    output logic             load_unsigned_o,

    //==========================================================================
    // Write Back
    //==========================================================================

    output wb_sel_t          wb_sel_o,

    //==========================================================================
    // Next PC
    //==========================================================================

    output pc_src_t          pc_src_o,
    output branch_type_t     branch_type_o

);

    //==========================================================================
    // Instruction Fields
    //==========================================================================

    logic [6:0] opcode;
    logic [2:0] funct3;

    assign opcode = instruction_i[6:0];
    assign funct3 = instruction_i[14:12];

    //==========================================================================
    // Main Decoder
    //==========================================================================

    always_comb begin

        //----------------------------------------------------------------------
        // Safe Defaults
        //----------------------------------------------------------------------

        reg_write_o      = 1'b0;

        alu_src_o        = 1'b0;
        alu_op_o         = ALU_OP_ADD;

        mem_read_o       = 1'b0;
        mem_write_o      = 1'b0;

        access_size_o    = WORD_ACCESS;
        load_unsigned_o  = 1'b0;

        wb_sel_o         = WB_ALU;

        pc_src_o         = PC_SEQ;
        branch_type_o    = BR_EQ;

        //----------------------------------------------------------------------
        // Opcode Decode
        //----------------------------------------------------------------------

        unique case(opcode)

            //==============================================================
            // R-Type
            //==============================================================

            OPCODE_RTYPE: begin

                reg_write_o = 1'b1;

                alu_src_o   = 1'b0;

                alu_op_o    = ALU_OP_RTYPE;

                wb_sel_o    = WB_ALU;

            end

            //==============================================================
            // I-Type ALU
            //==============================================================

            OPCODE_ITYPE: begin

                reg_write_o = 1'b1;

                alu_src_o   = 1'b1;

                alu_op_o    = ALU_OP_ITYPE;

                wb_sel_o    = WB_ALU;

            end

            //==============================================================
            // LOAD
            //==============================================================

            OPCODE_LOAD: begin

                reg_write_o = 1'b1;

                alu_src_o   = 1'b1;

                alu_op_o    = ALU_OP_ADD;

                mem_read_o  = 1'b1;

                wb_sel_o    = WB_MEM;

                unique case(funct3)

                    F3_LB: begin
                        access_size_o   = BYTE_ACCESS;
                        load_unsigned_o = 1'b0;
                    end

                    F3_LH: begin
                        access_size_o   = HALFWORD_ACCESS;
                        load_unsigned_o = 1'b0;
                    end

                    F3_LW: begin
                        access_size_o   = WORD_ACCESS;
                        load_unsigned_o = 1'b0;
                    end

                    F3_LBU: begin
                        access_size_o   = BYTE_ACCESS;
                        load_unsigned_o = 1'b1;
                    end

                    F3_LHU: begin
                        access_size_o   = HALFWORD_ACCESS;
                        load_unsigned_o = 1'b1;
                    end

                    default: begin
                    end

                endcase

            end

            //==============================================================
            // STORE
            //==============================================================

            OPCODE_STORE: begin

                alu_src_o   = 1'b1;

                alu_op_o    = ALU_OP_ADD;

                mem_write_o = 1'b1;

                unique case(funct3)

                    F3_SB : access_size_o = BYTE_ACCESS;

                    F3_SH : access_size_o = HALFWORD_ACCESS;

                    F3_SW : access_size_o = WORD_ACCESS;

                    default: begin
                    end

                endcase

            end

            //==============================================================
            // BRANCH
            //==============================================================

            OPCODE_BRANCH: begin

                alu_op_o = ALU_OP_BRANCH;

                pc_src_o = PC_BRANCH;

                unique case(funct3)

                    F3_BEQ  : branch_type_o = BR_EQ;

                    F3_BNE  : branch_type_o = BR_NE;

                    F3_BLT  : branch_type_o = BR_LT;

                    F3_BGE  : branch_type_o = BR_GE;

                    F3_BLTU : branch_type_o = BR_LTU;

                    F3_BGEU : branch_type_o = BR_GEU;

                    default : begin
                    end

                endcase

            end

            //==============================================================
            // JAL
            //==============================================================

            OPCODE_JAL: begin

                reg_write_o = 1'b1;

                wb_sel_o    = WB_PC4;

                pc_src_o    = PC_JAL;

            end

            //==============================================================
            // JALR
            //==============================================================

            OPCODE_JALR: begin

                reg_write_o = 1'b1;

                wb_sel_o    = WB_PC4;

                pc_src_o    = PC_JALR;

            end

            //==============================================================
            // LUI
            //==============================================================

            OPCODE_LUI: begin

                reg_write_o = 1'b1;

                wb_sel_o    = WB_IMM;

            end

            //==============================================================
            // AUIPC
            //==============================================================

            OPCODE_AUIPC: begin

                reg_write_o = 1'b1;

                wb_sel_o    = WB_AUIPC;

            end

            default: begin
            end

        endcase

    end

endmodule