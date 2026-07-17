import rv32i_pkg::*;

module next_pc_logic #(parameter int XLEN = 32,
    parameter int ADDR_WIDTH = XLEN)(
        input logic [ADDR_WIDTH-1:0] pc_plus4_i,
        input logic [ADDR_WIDTH-1:0] pc_plus_imm_i,
        input logic [ADDR_WIDTH-1:0] rs1_plus_imm_i,

        input logic eq_i,
        input logic lt_i,
        input logic ltu_i,

        input pc_src_t pc_src_i,
        input branch_type_t branch_type_i,

        output logic [ADDR_WIDTH-1:0] next_pc_o
    );

    always_comb begin

        next_pc_o = pc_plus4_i; 

        unique case(pc_src_i)

            PC_SEQ: next_pc_o = pc_plus4_i;

            PC_BRANCH:
                unique case(branch_type_i)
                
                BR_EQ: next_pc_o = eq_i? pc_plus_imm_i : pc_plus4_i;

                BR_NE: next_pc_o = !eq_i? pc_plus_imm_i : pc_plus4_i;

                BR_LT: next_pc_o = lt_i? pc_plus_imm_i : pc_plus4_i;

                BR_GE: next_pc_o = !lt_i? pc_plus_imm_i : pc_plus4_i;

                BR_LTU: next_pc_o = ltu_i? pc_plus_imm_i : pc_plus4_i;

                BR_GEU: next_pc_o = !ltu_i? pc_plus_imm_i : pc_plus4_i;
                
                endcase
            
            PC_JAL: next_pc_o = pc_plus_imm_i;

            PC_JALR: next_pc_o = rs1_plus_imm_i;

        endcase
        
    end

endmodule