import alu_pkg::*;

module alu_control(

    input  logic [1:0] alu_op_i,
    input  logic [2:0] funct3_i,
    input  logic [6:0] funct7_i,

    output alu_op_t    alu_op_o

);

    always_comb begin

        // Safe default
        alu_op_o = ALU_ADD;

        unique case (alu_op_i)

            //------------------------------------------------------------------
            // Fixed ADD (Loads, Stores, AUIPC default, etc.)
            //------------------------------------------------------------------
            2'b00: begin
                alu_op_o = ALU_ADD;
            end

            //------------------------------------------------------------------
            // Fixed SUB (Branches)
            //------------------------------------------------------------------
            2'b01: begin
                alu_op_o = ALU_SUB;
            end

            //------------------------------------------------------------------
            // R-Type Decode
            //------------------------------------------------------------------
            2'b10: begin

                unique case (funct3_i)

                    3'b000: begin
                        unique case (funct7_i)

                            7'b0000000 : alu_op_o = ALU_ADD;
                            7'b0100000 : alu_op_o = ALU_SUB;

                            default    : alu_op_o = ALU_ADD;

                        endcase
                    end

                    3'b001 : alu_op_o = ALU_SLL;
                    3'b010 : alu_op_o = ALU_SLT;
                    3'b011 : alu_op_o = ALU_SLTU;
                    3'b100 : alu_op_o = ALU_XOR;

                    3'b101: begin
                        unique case (funct7_i)

                            7'b0000000 : alu_op_o = ALU_SRL;
                            7'b0100000 : alu_op_o = ALU_SRA;

                            default    : alu_op_o = ALU_SRL;

                        endcase
                    end

                    3'b110 : alu_op_o = ALU_OR;
                    3'b111 : alu_op_o = ALU_AND;

                    default: alu_op_o = ALU_ADD;

                endcase

            end

            //------------------------------------------------------------------
            // I-Type ALU Decode
            //------------------------------------------------------------------
            2'b11: begin

                unique case (funct3_i)

                    3'b000 : alu_op_o = ALU_ADD;   // ADDI
                    3'b010 : alu_op_o = ALU_SLT;   // SLTI
                    3'b011 : alu_op_o = ALU_SLTU;  // SLTIU
                    3'b100 : alu_op_o = ALU_XOR;   // XORI
                    3'b110 : alu_op_o = ALU_OR;    // ORI
                    3'b111 : alu_op_o = ALU_AND;   // ANDI

                    3'b001 : alu_op_o = ALU_SLL;   // SLLI

                    3'b101: begin

                        unique case (funct7_i)

                            7'b0000000 : alu_op_o = ALU_SRL; // SRLI
                            7'b0100000 : alu_op_o = ALU_SRA; // SRAI

                            default    : alu_op_o = ALU_SRL;

                        endcase

                    end

                    default : alu_op_o = ALU_ADD;

                endcase

            end

            default: begin
                alu_op_o = ALU_ADD;
            end

        endcase

    end

endmodule