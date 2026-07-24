module alu_operand_mux #(
    parameter int XLEN = 32
)(
    //==========================================================================
    // Inputs
    //==========================================================================
    input  logic [XLEN-1:0] rs2_data_i,
    input  logic [XLEN-1:0] imm_i,
    input  logic            alu_src_i,

    //==========================================================================
    // Output
    //==========================================================================
    output logic [XLEN-1:0] operand_b_o
);

    //==========================================================================
    // ALU Operand B Multiplexer
    //==========================================================================
    always_comb begin
        unique case (alu_src_i)
            1'b0    : operand_b_o = rs2_data_i;
            1'b1    : operand_b_o = imm_i;
            default : operand_b_o = 'x;
        endcase
    end

endmodule