`timescale 1ns/1ps

module tb_branch_comparator;

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------

    localparam int DATA_WIDTH       = 32;
    localparam int NUM_RANDOM_TESTS = 500;

    localparam logic [DATA_WIDTH-1:0] ZERO         = '0;
    localparam logic [DATA_WIDTH-1:0] MAX_SIGNED   = 32'h7FFF_FFFF;
    localparam logic [DATA_WIDTH-1:0] MIN_SIGNED   = 32'h8000_0000;
    localparam logic [DATA_WIDTH-1:0] MAX_UNSIGNED = 32'hFFFF_FFFF;

    //--------------------------------------------------------------------------
    // DUT Signals
    //--------------------------------------------------------------------------

    logic [DATA_WIDTH-1:0] operand_a;
    logic [DATA_WIDTH-1:0] operand_b;

    logic eq;
    logic lt;
    logic ltu;

    //--------------------------------------------------------------------------
    // DUT
    //--------------------------------------------------------------------------

    branch_comparator #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .operand_a_i (operand_a),
        .operand_b_i (operand_b),

        .eq_o  (eq),
        .lt_o  (lt),
        .ltu_o (ltu)
    );

    //--------------------------------------------------------------------------
    // Golden Reference Functions
    //--------------------------------------------------------------------------

    function automatic logic expected_eq(
        input logic [DATA_WIDTH-1:0] a,
        input logic [DATA_WIDTH-1:0] b
    );
        expected_eq = (a == b);
    endfunction

    function automatic logic expected_lt(
        input logic [DATA_WIDTH-1:0] a,
        input logic [DATA_WIDTH-1:0] b
    );
        expected_lt = ($signed(a) < $signed(b));
    endfunction

    function automatic logic expected_ltu(
        input logic [DATA_WIDTH-1:0] a,
        input logic [DATA_WIDTH-1:0] b
    );
        expected_ltu = (a < b);
    endfunction

    //--------------------------------------------------------------------------
    // Helper Task
    //--------------------------------------------------------------------------

    task automatic run_test(
        input logic [DATA_WIDTH-1:0] a,
        input logic [DATA_WIDTH-1:0] b
    );

        logic exp_eq;
        logic exp_lt;
        logic exp_ltu;

        begin

            operand_a = a;
            operand_b = b;

            #1;

            exp_eq  = expected_eq(a,b);
            exp_lt  = expected_lt(a,b);
            exp_ltu = expected_ltu(a,b);

            assert(eq === exp_eq)
            else begin
                $error("EQ mismatch: A=%h B=%h Expected=%0b Got=%0b",
                       a,b,exp_eq,eq);
                $fatal;
            end

            assert(lt === exp_lt)
            else begin
                $error("LT mismatch: A=%h B=%h Expected=%0b Got=%0b",
                       a,b,exp_lt,lt);
                $fatal;
            end

            assert(ltu === exp_ltu)
            else begin
                $error("LTU mismatch: A=%h B=%h Expected=%0b Got=%0b",
                       a,b,exp_ltu,ltu);
                $fatal;
            end

        end

    endtask

    //--------------------------------------------------------------------------
    // Test Sequence
    //--------------------------------------------------------------------------

    initial begin

        //----------------------------------------------------------------------
        // Equality Tests
        //----------------------------------------------------------------------

        $display("\n========================================");
        $display("Running Equality Tests...");
        $display("========================================");

        run_test(32'd5,32'd5);
        run_test(ZERO,ZERO);
        run_test(MAX_UNSIGNED,MAX_UNSIGNED);

        //----------------------------------------------------------------------
        // Signed Comparison Tests
        //----------------------------------------------------------------------

        $display("\n========================================");
        $display("Running Signed Comparison Tests...");
        $display("========================================");

        run_test(32'd5,32'd10);
        run_test(32'd10,32'd5);

        run_test(-32'sd5,32'sd3);
        run_test(32'sd3,-32'sd5);

        run_test(-32'sd10,-32'sd5);
        run_test(-32'sd5,-32'sd10);

        //----------------------------------------------------------------------
        // Unsigned Comparison Tests
        //----------------------------------------------------------------------

        $display("\n========================================");
        $display("Running Unsigned Comparison Tests...");
        $display("========================================");

        run_test(MAX_UNSIGNED,32'd1);
        run_test(32'd1,MAX_UNSIGNED);

        //----------------------------------------------------------------------
        // Boundary Tests
        //----------------------------------------------------------------------

        $display("\n========================================");
        $display("Running Boundary Tests...");
        $display("========================================");

        run_test(MAX_SIGNED,MIN_SIGNED);
        run_test(MIN_SIGNED,MAX_SIGNED);

        run_test(ZERO,MAX_UNSIGNED);
        run_test(MAX_UNSIGNED,ZERO);

        run_test(MAX_SIGNED,MAX_SIGNED);
        run_test(MIN_SIGNED,MIN_SIGNED);

        //----------------------------------------------------------------------
        // Structured Random Tests
        //----------------------------------------------------------------------

        $display("\n========================================");
        $display("Running Structured Random Tests...");
        $display("========================================");

        repeat(NUM_RANDOM_TESTS) begin
            run_test($urandom,$urandom);
        end

        //----------------------------------------------------------------------
        // PASS
        //----------------------------------------------------------------------

        $display("\n========================================");
        $display(" ALL BRANCH COMPARATOR TESTS PASSED ");
        $display("========================================\n");

        $finish;

    end

endmodule