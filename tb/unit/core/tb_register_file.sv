```systemverilog
module tb_register_file();

    parameter int DATA_WIDTH = 32;
    parameter int NUM_REGS   = 32;

    logic clk;
    logic rst;

    logic [$clog2(NUM_REGS)-1:0] read_addr_1;
    logic [$clog2(NUM_REGS)-1:0] read_addr_2;

    logic                        write_enable;
    logic [$clog2(NUM_REGS)-1:0] write_addr;
    logic [DATA_WIDTH-1:0]       write_data;

    logic [DATA_WIDTH-1:0]       read_data_1;
    logic [DATA_WIDTH-1:0]       read_data_2;


    register_file #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_REGS(NUM_REGS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .read_addr_1(read_addr_1),
        .read_addr_2(read_addr_2),
        .read_data_1(read_data_1),
        .read_data_2(read_data_2),
        .write_enable(write_enable),
        .write_addr(write_addr),
        .write_data(write_data)
    );


    always #5 clk = ~clk;


    initial begin

        clk          = 0;
        rst          = 0;
        write_enable = 0;
        write_addr   = 0;
        write_data   = 0;
        read_addr_1  = 0;
        read_addr_2  = 0;

        // ---------------- Reset Test ----------------
        rst = 1;
        #3 rst = 0;
        #3;

        read_addr_1 = 5;
        read_addr_2 = 10;

        #1;

        if (read_data_1 == 0 && read_data_2 == 0) begin
            $display("RESET TEST PASSED");
        end
        else begin
            $display("RESET TEST FAILED");
        end


        // ---------------- Write Test ----------------
        write_enable = 1;
        write_addr   = 5;
        write_data   = 50;

        @(posedge clk);

        write_addr = 10;
        write_data = 200;

        @(posedge clk);

        #1 write_enable = 0;

        read_addr_1 = 5;
        read_addr_2 = 10;

        #1;

        if (read_data_1 == 50 && read_data_2 == 200) begin
            $display("WRITE TEST PASSED");
        end
        else begin
            $display("WRITE TEST FAILED");
        end


        // ---------------- x0 Protection Test ----------------
        read_addr_1 = 0;
        read_addr_2 = 10;

        @(posedge clk);

        write_enable = 1;
        write_addr   = 0;
        write_data   = 200;

        @(posedge clk);

        #1 write_enable = 0;

        read_addr_1 = 0;
        read_addr_2 = 10;

        #1;

        if (read_data_1 == 0) begin
            $display("WRITE TO 0 PREVENTED");
        end
        else begin
            $display("WRITE TO 0 NOT PROTECTED");
        end


        // ---------------- Write-First Test ----------------
        write_enable = 1;
        write_addr   = 10;
        write_data   = 150;

        read_addr_1 = 0;
        read_addr_2 = 10;

        #1;

        if (read_data_2 == 150) begin
            $display("WRITE-FIRST IMPLEMENTED");
        end
        else begin
            $display("WRITE-FIRST FAILED");
        end

        @(posedge clk);

        #1 write_enable = 0;


        // ---------------- Dual-Port Forwarding Test ----------------
        write_enable = 1;
        write_addr   = 5;
        write_data   = 91;

        read_addr_1 = 5;
        read_addr_2 = 5;

        #1;

        if (read_data_1 == 91 && read_data_2 == 91) begin
            $display("BOTH PORTS FORWARDING");
        end
        else begin
            $display("BOTH PORTS NOT FORWARDING");
        end

        @(posedge clk);

        #1 write_enable = 0;


        repeat (5)
            @(posedge clk);

        $finish;

    end


    initial begin
        $monitor(
            "The register %d has value %d and the register %d has value %d",
            read_addr_1,
            read_data_1,
            read_addr_2,
            read_data_2
        );
    end

endmodule
```
