import alu_pkg::*;

module alu_control(
    input logic [1:0] alu_op_i,
    input logic [2:0] funct3_i,
    input logic [6:0] funct7_i,

    output alu_op_t   alu_op_o
    );

    always_comb begin

        alu_op_o = ALU_ADD;

        unique case (alu_op_i)
            2'b00:
                alu_op_o = ALU_ADD;

            2'b01:
                alu_op_o = ALU_SUB;

            2'b10:
                unique case (funct3_i)
                    3'b000:

                        unique case(funct7_i)
                            7'b0000000:
                                alu_op_o = ALU_ADD;

                            7'b0100000: 
                                alu_op_o= ALU_SUB;
                        endcase
                
                    3'b001:
                        alu_op_o = ALU_SLL;

                    3'b010:
                        alu_op_o = ALU_SLT;

                    3'b011:
                        alu_op_o = ALU_SLTU;

                    3'b100:
                        alu_op_o = ALU_XOR;

                    3'b101: 

                        unique case(funct7_i) 
                            7'b0000000:
                                alu_op_o = ALU_SRL;
                           
                            7'b0100000: 
                                alu_op_o = ALU_SRA;
                        endcase

                    3'b110: 
                        alu_op_o = ALU_OR;

                    3'b111:
                        alu_op_o = ALU_AND;
 
                endcase
        
    endcase

    end

endmodule