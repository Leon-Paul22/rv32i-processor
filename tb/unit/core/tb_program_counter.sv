parameter int ADDR_WIDTH = 32;
parameter logic [ADDR_WIDTH-1:0] RESET_ADDR = '0;

module tb_program_counter;

    logic clk_i;
    logic rst_i;
    logic pc_enable_i;
    logic [ADDR_WIDTH-1:0] next_pc_i;

    logic [ADDR_WIDTH-1:0] pc_o;

    program_counter dut(
        .clk_i(clk_i),
        .rst_i(rst_i),
        .pc_enable_i(pc_enable_i),
        .next_pc_i(next_pc_i),

        .pc_o(pc_o));

    logic [ADDR_WIDTH-1:0] expected_value;
    logic [ADDR_WIDTH-1:0] previous_expected_pc;

    int passed_tests;
    int failed_tests;

    always #5 clk_i = ~clk_i;

    function logic [ADDR_WIDTH-1:0] expected_pc(
        input logic rst,
        input logic pc_enable,
        input logic [ADDR_WIDTH-1:0] next_pc
    );
    begin
        if (rst)
            expected_pc = RESET_ADDR;
        else if (pc_enable)
            expected_pc = next_pc;
        else
            expected_pc = previous_expected_pc;
    end       
    endfunction

   task check_run(
    input  logic                  rst,
    input  logic                  pc_enable,
    input  logic [ADDR_WIDTH-1:0] next_pc);
    begin
        rst_i = rst;
        pc_enable_i = pc_enable;
        next_pc_i = next_pc;
        previous_expected_pc = expected_value;
        @(posedge clk_i);
        
        #1;

        expected_value = expected_pc(
            rst,
            pc_enable,
            next_pc);
        
        assert(pc_o == expected_value)
        else   begin
            $display(
                    "Test failed for:\n\
                    reset = %0d\n\
                    pc_enable = %0d\n\
                    next_pc = %0h\n\
                    pc_o = %0h\n\
                    expected_pc_o = %0h",
                    rst_i,
                    pc_enable_i,
                    next_pc_i,
                    pc_o,
                    expected_value
                    );
        end

        if (pc_o == expected_value)
            passed_tests++;
        else
            failed_tests++;
    end
   endtask

   initial begin
    clk_i = 0;
    rst_i = 1;
    pc_enable_i = 0;
    expected_value = RESET_ADDR;
    previous_expected_pc = RESET_ADDR;
    @(posedge clk_i);

    repeat(3) begin
        check_run(1, $urandom_range(1,0), $urandom);
    end

    repeat(100) begin
        check_run(0, $urandom_range(1,0), $urandom);
    end

    repeat(5) begin
        @(posedge clk_i);
    end

    $display("--------------------------------");
    $display("Passed Tests = %0d", passed_tests);
    $display("Failed Tests = %0d", failed_tests);
    $display("--------------------------------");

    
    $finish;

    end



endmodule