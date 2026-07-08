module instruction_memory #(
    parameter int    DEPTH            = 256,
    parameter int    INSTR_ADDR_WIDTH = 32,
    parameter int    INSTR_WIDTH      = 32,
    parameter string MEM_FILE         = "program.hex"
)(
    input  logic [INSTR_ADDR_WIDTH-1:0] pc_i,
    output logic [INSTR_WIDTH-1:0]      instruction_o
);

    localparam int MEM_ADDR_WIDTH = $clog2(DEPTH);

    logic [INSTR_WIDTH-1:0] instr_mem [0:DEPTH-1];
    logic [MEM_ADDR_WIDTH-1:0] instr_addr;

    initial begin
        $readmemh(MEM_FILE, instr_mem);
    end

    // Convert byte address into word index
    assign instr_addr    = pc_i[MEM_ADDR_WIDTH+1:2];

    // Combinational instruction fetch
    assign instruction_o = instr_mem[instr_addr];

endmodule