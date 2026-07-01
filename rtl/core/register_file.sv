module register_file #(
    parameter int DATA_WIDTH = 32,
    parameter int NUM_REGS = 32
)(
    input logic clk,
    input logic rst,
    input logic [$clog2(NUM_REGS)-1:0] read_addr_1,
    input logic [$clog2(NUM_REGS)-1:0] read_addr_2,
    input logic write_enable,
    input logic [$clog2(NUM_REGS)-1:0] write_addr,
    input logic [DATA_WIDTH-1:0] write_data,
    output logic [DATA_WIDTH-1:0] read_data_1,
    output logic [DATA_WIDTH-1:0] read_data_2
);

    // Parameter checks
    initial begin
        assert (NUM_REGS > 0)
        else
            $error("NUM_REGS must be positive");

        // NUM_REGS should be a power of two for proper address sizing
        assert ((NUM_REGS & (NUM_REGS-1)) == 0)
        else
            $error("NUM_REGS (%0d) must be a power of 2", NUM_REGS);
    end

    // Storage array for architectural registers
    logic [DATA_WIDTH-1:0] reg_arr [0:NUM_REGS-1];

    int unsigned i;

    // Synchronous write, asynchronous reset
    always_ff @(posedge clk or posedge rst)
    begin
        if (rst)
        begin
            // Clear all registers during reset
            for(i=0; i<NUM_REGS; i++)
            begin
                reg_arr[i] <= '0;
            end
        end
        else begin

            // Ignore writes to x0
            if (write_enable && write_addr!='0) begin
                reg_arr[write_addr] <= write_data;
            end

            // x0 must always remain zero
            reg_arr[0] <= '0;
        end
    end

    // Two independent combinational read ports
    always_comb begin

        // Read port 1
        if (read_addr_1=='0) begin
            read_data_1 = '0;
        end

        // Write-first behaviour
        else if (read_addr_1==write_addr && write_enable) begin
            read_data_1 = write_data;
        end

        else begin
            read_data_1 = reg_arr[read_addr_1];
        end

        // Read port 2
        if (read_addr_2=='0) begin
            read_data_2 = '0;
        end

        // Write-first behaviour
        else if (read_addr_2==write_addr && write_enable) begin
            read_data_2 = write_data;
        end

        else begin
            read_data_2 = reg_arr[read_addr_2];
        end

    end

endmodule