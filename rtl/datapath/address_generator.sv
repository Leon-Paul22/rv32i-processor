module address_generator #(
    parameter int XLEN = 32,
    parameter int ADDR_WIDTH = XLEN
)(
    input logic [ADDR_WIDTH-1:0] pc_i,
    input logic [XLEN-1:0] imm_i,
    input logic [XLEN-1:0] rs1_data_i,

    output logic [ADDR_WIDTH-1:0] pc_plus4_o,
    output logic [ADDR_WIDTH-1:0] pc_plus_imm_o,
    output logic [ADDR_WIDTH-1:0] rs1_plus_imm_o
);
    localparam logic [XLEN-1:0] JALR_ALIGN_MASK =
        {{(XLEN-1){1'b1}},1'b0};

    assign pc_plus4_o = pc_i + ADDR_WIDTH'(4);

    assign pc_plus_imm_o = pc_i + imm_i;

    assign rs1_plus_imm_o =
        (rs1_data_i + imm_i) & JALR_ALIGN_MASK;
endmodule