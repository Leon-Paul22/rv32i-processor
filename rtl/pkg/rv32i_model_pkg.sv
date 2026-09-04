//==============================================================================
// rv32i_model_pkg.sv
//==============================================================================
//
// Shared golden-model functions for the datapath and processor testbenches.
// Each function is written independently from the RTL, from the RV32I ISA
// definition - same discipline as tb_main_control.sv's golden_model().
//
// Scope note: LOAD/STORE testing in both testbenches is restricted to
// word-aligned LW/SW. Byte/halfword access sizes are already decoded and
// checked in tb_main_control.sv; re-deriving the byte-lane extract/merge
// logic here would roughly double this package for modest extra value at
// this stage. It's a natural next exercise if you want to extend this.
//
//==============================================================================

package rv32i_model_pkg;

    import rv32i_pkg::*;
    import alu_pkg::*;

    //==========================================================================
    // Control Signal Bundle
    //==========================================================================

    typedef struct packed {
        logic             reg_write;
        logic             alu_src;
        alu_ctrl_sel_t    alu_op;
        logic             mem_read;
        logic             mem_write;
        mem_access_size_t access_size;
        logic             load_unsigned;
        wb_sel_t          wb_sel;
        pc_src_t          pc_src;
        branch_type_t     branch_type;
    } control_signals_t;

    //==========================================================================
    // decode_control()
    //   Golden decode table, independently re-derived from the ISA - same
    //   function tb_main_control.sv's golden_model() computes, reused here
    //   so the datapath/processor testbenches don't re-derive it a third
    //   time. Used to drive stimulus in tb_rv32i_datapath.sv (main_control
    //   isn't part of that DUT) and to know what *should* happen in
    //   tb_rv32i_processor.sv.
    //==========================================================================

    function automatic control_signals_t decode_control(logic [31:0] instr);

        control_signals_t c;
        logic [6:0] op;
        logic [2:0] f3;

        op = instr[6:0];
        f3 = instr[14:12];

        c.reg_write     = 1'b0;
        c.alu_src       = 1'b0;
        c.alu_op        = ALU_OP_ADD;
        c.mem_read      = 1'b0;
        c.mem_write     = 1'b0;
        c.access_size   = WORD_ACCESS;
        c.load_unsigned = 1'b0;
        c.wb_sel        = WB_ALU;
        c.pc_src        = PC_SEQ;
        c.branch_type   = BR_EQ;

        unique case (op)

            OPCODE_RTYPE: begin
                c.reg_write = 1'b1;
                c.alu_op    = ALU_OP_RTYPE;
            end

            OPCODE_ITYPE: begin
                c.reg_write = 1'b1;
                c.alu_src   = 1'b1;
                c.alu_op    = ALU_OP_ITYPE;
            end

            OPCODE_LOAD: begin
                c.reg_write = 1'b1;
                c.alu_src   = 1'b1;
                c.alu_op    = ALU_OP_ADD;
                c.mem_read  = 1'b1;
                c.wb_sel    = WB_MEM;
            end

            OPCODE_STORE: begin
                c.alu_src   = 1'b1;
                c.alu_op    = ALU_OP_ADD;
                c.mem_write = 1'b1;
            end

            OPCODE_BRANCH: begin
                c.alu_op = ALU_OP_BRANCH;
                c.pc_src = PC_BRANCH;
                unique case (f3)
                    F3_BEQ:  c.branch_type = BR_EQ;
                    F3_BNE:  c.branch_type = BR_NE;
                    F3_BLT:  c.branch_type = BR_LT;
                    F3_BGE:  c.branch_type = BR_GE;
                    F3_BLTU: c.branch_type = BR_LTU;
                    F3_BGEU: c.branch_type = BR_GEU;
                    default: ; // Unreachable under branch_c
                endcase
            end

            OPCODE_JAL: begin
                c.reg_write = 1'b1;
                c.wb_sel    = WB_PC4;
                c.pc_src    = PC_JAL;
            end

            OPCODE_JALR: begin
                c.reg_write = 1'b1;
                c.wb_sel    = WB_PC4;
                c.pc_src    = PC_JALR;
            end

            OPCODE_LUI: begin
                c.reg_write = 1'b1;
                c.wb_sel    = WB_IMM;
            end

            OPCODE_AUIPC: begin
                c.reg_write = 1'b1;
                c.wb_sel    = WB_AUIPC;
            end

            default: ; // Illegal opcode - defaults hold

        endcase

        return c;

    endfunction

    //==========================================================================
    // sext()
    //   Sign-extends the low `width` bits of value to 32 bits.
    //==========================================================================

    function automatic logic [31:0] sext(logic [31:0] value, int width);
        logic [31:0] mask;
        mask = (32'b1 << width) - 32'b1;
        return value[width-1] ? (value | ~mask) : (value & mask);
    endfunction

    //==========================================================================
    // compute_immediate()
    //   Golden immediate decode, from the RV32I encoding tables.
    //==========================================================================

    function automatic logic [31:0] compute_immediate(logic [31:0] instr);
        logic [6:0] op;
        op = instr[6:0];
        unique case (op)
            OPCODE_ITYPE, OPCODE_LOAD, OPCODE_JALR:
                compute_immediate = sext(instr[31:20], 12);
            OPCODE_STORE:
                compute_immediate = sext({instr[31:25], instr[11:7]}, 12);
            OPCODE_BRANCH:
                compute_immediate = sext({instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}, 13);
            OPCODE_LUI, OPCODE_AUIPC:
                compute_immediate = {instr[31:12], 12'b0};
            OPCODE_JAL:
                compute_immediate = sext({instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}, 21);
            default:
                compute_immediate = 32'b0;
        endcase
    endfunction

    //==========================================================================
    // compute_alu_result()
    //   Golden ALU result. Takes the same 2-bit selector + funct3/funct7
    //   the real alu_control -> alu chain sees, but computes the
    //   arithmetic independently.
    //==========================================================================

    function automatic logic [31:0] compute_alu_result(
        logic [31:0]   operand_a,
        logic [31:0]   operand_b,
        alu_ctrl_sel_t alu_sel,
        logic [2:0]    funct3,
        logic [6:0]    funct7
    );
        alu_op_t     op;
        logic [4:0]  shamt;
        logic [31:0] result;

        op = ALU_ADD;

        unique case (alu_sel)

            ALU_OP_ADD:    op = ALU_ADD;
            ALU_OP_BRANCH: op = ALU_SUB;

            ALU_OP_RTYPE, ALU_OP_ITYPE: begin
                unique case (funct3)
                    3'b000:  op = alu_op_t'((alu_sel == ALU_OP_RTYPE && funct7 == 7'b0100000)
                                            ? ALU_SUB : ALU_ADD);
                    3'b001:  op = ALU_SLL;
                    3'b010:  op = ALU_SLT;
                    3'b011:  op = ALU_SLTU;
                    3'b100:  op = ALU_XOR;
                    3'b101:  op = alu_op_t'((funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL);
                    3'b110:  op = ALU_OR;
                    3'b111:  op = ALU_AND;
                    default: op = ALU_ADD;
                endcase
            end

            default: op = ALU_ADD;

        endcase

        shamt = operand_b[4:0]; // R-type: rs2_data[4:0]; I-type: immediate[4:0]

        unique case (op)
            ALU_ADD:  result = operand_a + operand_b;
            ALU_SUB:  result = operand_a - operand_b;
            ALU_AND:  result = operand_a & operand_b;
            ALU_OR:   result = operand_a | operand_b;
            ALU_XOR:  result = operand_a ^ operand_b;
            ALU_SLL:  result = operand_a << shamt;
            ALU_SRL:  result = operand_a >> shamt;
            ALU_SRA:  result = 32'($signed(operand_a) >>> shamt);
            ALU_SLT:  result = {31'b0, ($signed(operand_a) < $signed(operand_b))};
            ALU_SLTU: result = {31'b0, (operand_a < operand_b)};
            default:  result = 32'b0;
        endcase

        return result;

    endfunction

    //==========================================================================
    // compute_next_pc()
    //   Branch resolution + next-PC selection in one place: given the
    //   current pc, the immediate, rs1/rs2, and the control signals,
    //   returns what pc should become next.
    //==========================================================================

    function automatic logic [31:0] compute_next_pc(
        logic [31:0]  pc,
        logic [31:0]  imm,
        logic [31:0]  rs1_val,
        logic [31:0]  rs2_val,
        pc_src_t      pc_src,
        branch_type_t branch_type
    );
        logic [31:0] pc_plus4, pc_plus_imm, rs1_plus_imm;
        logic        eq, lt, ltu, taken;

        pc_plus4     = pc + 32'd4;
        pc_plus_imm  = pc + imm;
        rs1_plus_imm = (rs1_val + imm) & ~32'b1; // JALR clears the LSB

        eq  = (rs1_val == rs2_val);
        lt  = ($signed(rs1_val) < $signed(rs2_val));
        ltu = (rs1_val < rs2_val);

        unique case (branch_type)
            BR_EQ:   taken = eq;
            BR_NE:   taken = !eq;
            BR_LT:   taken = lt;
            BR_GE:   taken = !lt;
            BR_LTU:  taken = ltu;
            BR_GEU:  taken = !ltu;
            default: taken = 1'b0;
        endcase

        unique case (pc_src)
            PC_SEQ:    return pc_plus4;
            PC_BRANCH: return taken ? pc_plus_imm : pc_plus4;
            PC_JAL:    return pc_plus_imm;
            PC_JALR:   return rs1_plus_imm;
            default:   return pc_plus4;
        endcase

    endfunction

    //==========================================================================
    // compute_writeback_data()
    //   mem_data is the full memory word - LOAD/STORE testing is
    //   word-aligned only, so no byte-lane extraction is needed (see the
    //   file header note).
    //==========================================================================

    function automatic logic [31:0] compute_writeback_data(
        wb_sel_t     wb_sel,
        logic [31:0] alu_result,
        logic [31:0] mem_data,
        logic [31:0] pc,
        logic [31:0] imm
    );
        unique case (wb_sel)
            WB_ALU:   return alu_result;
            WB_MEM:   return mem_data;
            WB_PC4:   return pc + 32'd4;
            WB_AUIPC: return pc + imm;
            WB_IMM:   return imm;
            default:  return 32'b0;
        endcase
    endfunction

    //==========================================================================
    // encode_instruction()
    //   Assembles a 32-bit instruction from its fields - the inverse of
    //   compute_immediate(). Shared by both testbenches so instructions
    //   are always built the same way.
    //==========================================================================

    function automatic logic [31:0] encode_instruction(
        logic [6:0]  opcode,
        logic [2:0]  funct3,
        logic [6:0]  funct7,
        logic [4:0]  rs1,
        logic [4:0]  rs2,
        logic [4:0]  rd,
        logic [31:0] imm
    );
        logic [31:0] instr;
        instr = 32'b0;
        instr[6:0] = opcode;

        unique case (opcode)

            OPCODE_RTYPE: begin
                instr[11:7]  = rd;
                instr[14:12] = funct3;
                instr[19:15] = rs1;
                instr[24:20] = rs2;
                instr[31:25] = funct7;
            end

            OPCODE_ITYPE, OPCODE_LOAD, OPCODE_JALR: begin
                instr[11:7]  = rd;
                instr[14:12] = funct3;
                instr[19:15] = rs1;
                instr[31:20] = imm[11:0];
            end

            OPCODE_STORE: begin
                instr[14:12] = funct3;
                instr[19:15] = rs1;
                instr[24:20] = rs2;
                instr[11:7]  = imm[4:0];
                instr[31:25] = imm[11:5];
            end

            OPCODE_BRANCH: begin
                instr[14:12] = funct3;
                instr[19:15] = rs1;
                instr[24:20] = rs2;
                instr[7]     = imm[11];
                instr[11:8]  = imm[4:1];
                instr[30:25] = imm[10:5];
                instr[31]    = imm[12];
            end

            OPCODE_LUI, OPCODE_AUIPC: begin
                instr[11:7]  = rd;
                instr[31:12] = imm[19:0];
            end

            OPCODE_JAL: begin
                instr[11:7]  = rd;
                instr[19:12] = imm[19:12];
                instr[20]    = imm[11];
                instr[30:21] = imm[10:1];
                instr[31]    = imm[20];
            end

            default: ; // Unreachable for the 9 legal opcodes

        endcase

        return instr;

    endfunction

endpackage
