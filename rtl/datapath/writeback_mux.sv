import rv32i_pkg::*;

module writeback_mux #(
    parameter int XLEN = 32
)(
    //--------------------------------------------------------------------------
    // Inputs
    //--------------------------------------------------------------------------

    input  logic [XLEN-1:0] alu_result_i,
    input  logic [XLEN-1:0] mem_data_i,
    input  logic [XLEN-1:0] pc_plus4_i,
    input  logic [XLEN-1:0] pc_plus_imm_i,
    input  logic [XLEN-1:0] imm_i,

    input  wb_sel_t         wb_sel_i,

    //--------------------------------------------------------------------------
    // Output
    //--------------------------------------------------------------------------

    output logic [XLEN-1:0] wb_data_o
);

    //--------------------------------------------------------------------------
    // Write Back MUX
    //--------------------------------------------------------------------------

    always_comb begin
        unique case (wb_sel_i)

            WB_ALU   : wb_data_o = alu_result_i;

            WB_MEM   : wb_data_o = mem_data_i;

            WB_PC4   : wb_data_o = pc_plus4_i;

            WB_AUIPC : wb_data_o = pc_plus_imm_i;

            WB_IMM   : wb_data_o = imm_i;

            default  : wb_data_o = 'x;

        endcase
    end

endmodule