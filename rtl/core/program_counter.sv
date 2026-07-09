module program_counter #(
    parameter int ADDR_WIDTH = 32,
    parameter logic [ADDR_WIDTH-1:0] RESET_ADDR = '0
)(
    input  logic                  clk_i,
    input  logic                  rst_i,
    input  logic                  pc_enable_i,
    input  logic [ADDR_WIDTH-1:0] next_pc_i,

    output logic [ADDR_WIDTH-1:0] pc_o
);

    always_ff @(posedge clk_i)
    begin
        if (rst_i)
            pc_o <= RESET_ADDR;
        else if (pc_enable_i)
            pc_o <= next_pc_i;
    end

endmodule