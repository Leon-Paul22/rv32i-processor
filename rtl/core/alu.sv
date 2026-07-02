import alu_pkg::*;

module alu #(parameter int DATA_WIDTH = 32)(
    input logic [DATA_WIDTH-1:0] operand_a,
    input logic [DATA_WIDTH-1:0] operand_b,
    input alu_op_t               alu_op,
    output logic [DATA_WIDTH-1:0] result,
    output logic                 zero_flag
);
    localparam int SHIFT_WIDTH = $clog2(DATA_WIDTH);

    logic [DATA_WIDTH-1:0] operand_b_mod;
    logic add_sub_sel;

    logic [DATA_WIDTH:0] add_sub_result_ext;
    logic [DATA_WIDTH-1:0] add_sub_result;

    logic [DATA_WIDTH-1:0] and_result;
    logic [DATA_WIDTH-1:0] or_result;
    logic [DATA_WIDTH-1:0] xor_result;

    logic [DATA_WIDTH-1:0] sll_result;
    logic [DATA_WIDTH-1:0] srl_result;
    logic [DATA_WIDTH-1:0] sra_result;

    logic carry_in;
    logic carry_out;
    logic sub_overflow;

    logic signed_less_than;
    logic unsigned_less_than;

    always_comb begin : alu_computation
        result = '0;
        add_sub_sel =
            (alu_op == ALU_SUB)
        ||  (alu_op == ALU_SLT)
        ||  (alu_op == ALU_SLTU);

        operand_b_mod =
            add_sub_sel ?
            ~operand_b:
            operand_b;

        carry_in =
            add_sub_sel ?
                1'b1 :
                1'b0;

        add_sub_result_ext =
              {1'b0, operand_a}
            + {1'b0, operand_b_mod}
            + carry_in;

        add_sub_result = add_sub_result_ext[DATA_WIDTH-1:0];
        carry_out = add_sub_result_ext[DATA_WIDTH];
        sub_overflow = (operand_a[DATA_WIDTH-1]!=operand_b[DATA_WIDTH-1]) && (add_sub_result[DATA_WIDTH-1]!=operand_a[DATA_WIDTH-1]);

        and_result = operand_a & operand_b;
        or_result = operand_a | operand_b;
        xor_result = operand_a ^ operand_b;

        sll_result = operand_a << operand_b[SHIFT_WIDTH-1:0];
        srl_result = operand_a >> operand_b[SHIFT_WIDTH-1:0];
        sra_result = $signed(operand_a) >>> operand_b[SHIFT_WIDTH-1:0];
        
        unsigned_less_than = ~carry_out;
        signed_less_than = add_sub_result[DATA_WIDTH-1] ^ sub_overflow;
        unique case (alu_op)
            ALU_ADD: result = add_sub_result;
            ALU_SUB: result = add_sub_result;
            
            ALU_AND: result = and_result;
            ALU_OR: result = or_result;
            ALU_XOR: result = xor_result;
            
            ALU_SLL: result = sll_result;
            ALU_SRL: result = srl_result;
            ALU_SRA: result = sra_result;

            ALU_SLT: result = {{(DATA_WIDTH-1){1'b0}}, signed_less_than};
            ALU_SLTU: result = {{(DATA_WIDTH-1){1'b0}}, unsigned_less_than};

            default:;
        
        endcase

    end
    
    assign zero_flag = (result == '0);

endmodule



