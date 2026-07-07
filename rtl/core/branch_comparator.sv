module branch_comparator #(
    parameter DATA_WIDTH = 32
) (
    input logic [DATA_WIDTH-1:0] operand_a_i,
    input logic [DATA_WIDTH-1:0] operand_b_i,

    output logic eq_o,
    output logic lt_o,
    output logic ltu_o
);

    assign eq_o  = (operand_a_i == operand_b_i);

    assign lt_o  = ($signed(operand_a_i) < $signed(operand_b_i));

    assign ltu_o = (operand_a_i < operand_b_i);

endmodule