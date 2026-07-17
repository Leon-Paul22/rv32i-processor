//==========================================================================
// rv32i_pkg.sv
//==========================================================================

`ifndef RV32I_PKG_SV
`define RV32I_PKG_SV

package rv32i_pkg;

    //==========================================================================
    // RV32I Opcode Definitions
    //==========================================================================

    localparam logic [6:0] OPCODE_RTYPE   = 7'b0110011;
    localparam logic [6:0] OPCODE_ITYPE   = 7'b0010011;
    localparam logic [6:0] OPCODE_LOAD    = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE   = 7'b0100011;
    localparam logic [6:0] OPCODE_BRANCH  = 7'b1100011;
    localparam logic [6:0] OPCODE_JALR    = 7'b1100111;
    localparam logic [6:0] OPCODE_JAL     = 7'b1101111;
    localparam logic [6:0] OPCODE_LUI     = 7'b0110111;
    localparam logic [6:0] OPCODE_AUIPC   = 7'b0010111;

    //==========================================================================
    // Funct3 Definitions
    //==========================================================================

    // Loads
    localparam logic [2:0] F3_LB   = 3'b000;
    localparam logic [2:0] F3_LH   = 3'b001;
    localparam logic [2:0] F3_LW   = 3'b010;
    localparam logic [2:0] F3_LBU  = 3'b100;
    localparam logic [2:0] F3_LHU  = 3'b101;

    // Stores
    localparam logic [2:0] F3_SB   = 3'b000;
    localparam logic [2:0] F3_SH   = 3'b001;
    localparam logic [2:0] F3_SW   = 3'b010;

    // Branches
    localparam logic [2:0] F3_BEQ  = 3'b000;
    localparam logic [2:0] F3_BNE  = 3'b001;
    localparam logic [2:0] F3_BLT  = 3'b100;
    localparam logic [2:0] F3_BGE  = 3'b101;
    localparam logic [2:0] F3_BLTU = 3'b110;
    localparam logic [2:0] F3_BGEU = 3'b111;

    //==========================================================================
    // ALU Control Selection
    //==========================================================================

    typedef enum logic [1:0] {
        ALU_OP_ADD      = 2'b00,
        ALU_OP_BRANCH   = 2'b01,
        ALU_OP_RTYPE    = 2'b10,
        ALU_OP_ITYPE    = 2'b11
    } alu_ctrl_sel_t;

    //==========================================================================
    // Memory Access Size
    //==========================================================================

    typedef enum logic [1:0] {
        BYTE_ACCESS      = 2'b00,
        HALFWORD_ACCESS  = 2'b01,
        WORD_ACCESS      = 2'b10
    } mem_access_size_t;

    //==========================================================================
    // Write Back Selection
    //==========================================================================

    typedef enum logic [2:0] {
        WB_ALU      = 3'b000,
        WB_MEM      = 3'b001,
        WB_PC4      = 3'b010,
        WB_AUIPC    = 3'b011,
        WB_IMM      = 3'b100
    } wb_sel_t;

    //==========================================================================
    // Next PC Source
    //==========================================================================

    typedef enum logic [1:0] {
        PC_SEQ      = 2'b00,
        PC_BRANCH   = 2'b01,
        PC_JAL      = 2'b10,
        PC_JALR     = 2'b11
    } pc_src_t;

    //==========================================================================
    // Branch Type
    //==========================================================================

    typedef enum logic [2:0] {
        BR_EQ       = 3'b000,
        BR_NE       = 3'b001,
        BR_LT       = 3'b010,
        BR_GE       = 3'b011,
        BR_LTU      = 3'b100,
        BR_GEU      = 3'b101
    } branch_type_t;

endpackage

`endif