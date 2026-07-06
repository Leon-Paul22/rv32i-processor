typedef enum logic [6:0] {
    R_TYPE      = 7'b0110011,
    I_TYPE_ALU  = 7'b0010011,
    I_TYPE_LOAD = 7'b0000011,
    I_TYPE_JALR = 7'b1100111,
    S_TYPE      = 7'b0100011,
    B_TYPE      = 7'b1100011,
    U_TYPE_LUI  = 7'b0110111,
    U_TYPE_AUIPC= 7'b0010111,
    J_TYPE      = 7'b1101111
} instr_type_t;


module immediate_generator #(parameter int XLEN = 32)(
    input logic [31:0] instruction_i,
    output logic [XLEN-1:0] immediate_o
);
    
    instr_type_t instr_type;
    logic [6:0] opcode;

    always_comb
    begin
        immediate_o = '0;
        opcode = instruction_i[6:0];
        instr_type = instr_type_t'(opcode);
        unique case (instr_type)

            I_TYPE_ALU,
            I_TYPE_LOAD,
            I_TYPE_JALR: immediate_o = {{XLEN-12{instruction_i[31]}}, instruction_i[31:20]};

            S_TYPE:  immediate_o = {{XLEN-12{instruction_i[31]}},instruction_i[31:25],instruction_i[11:7]};

            B_TYPE: immediate_o = {{XLEN-13{instruction_i[31]}}, instruction_i[31],instruction_i[7],instruction_i[30:25], instruction_i[11:8], 1'b0};

            U_TYPE_LUI,
            U_TYPE_AUIPC: immediate_o = {{XLEN-32{instruction_i[31]}}, instruction_i[31:12], 12'b0};
            
            J_TYPE: immediate_o = {{XLEN-21{instruction_i[31]}}, instruction_i[31], instruction_i[19:12], instruction_i[20], instruction_i[30:21], 1'b0};
                
        endcase
    end

endmodule