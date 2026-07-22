`timescale 1ns / 1ps

module tb_data_memory;

    //==========================================================================
    // Parameters
    //==========================================================================

    localparam int XLEN             = 32;
    localparam int MEM_DEPTH        = 1024;
    localparam int NUM_RANDOM_TESTS = 1000;

    //==========================================================================
    // DUT Signals
    //==========================================================================

    logic                     clk;

    logic                     mem_read;
    logic                     mem_write;

    logic [XLEN-1:0]          addr;
    logic [XLEN-1:0]          write_data;

    mem_access_size_t         access_size;
    logic                     load_unsigned;

    logic [XLEN-1:0]          read_data;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================

    data_memory #(
        .XLEN      (XLEN),
        .MEM_DEPTH (MEM_DEPTH)
    ) dut (
        .clk_i            (clk),
        .mem_read_i       (mem_read),
        .mem_write_i      (mem_write),
        .addr_i           (addr),
        .write_data_i     (write_data),
        .access_size_i    (access_size),
        .load_unsigned_i  (load_unsigned),
        .read_data_o      (read_data)
    );

    //==========================================================================
    // Golden Reference Memory
    // Independent byte-addressable memory model
    //==========================================================================

    logic [7:0] golden_mem [0:(MEM_DEPTH * 4)-1];

    //==========================================================================
    // Helper Variables
    //==========================================================================

    logic [XLEN-1:0] expected_data;

    int total_tests;
    int passed_tests;
    int failed_tests;

    //==========================================================================
    // Clock Generation
    //==========================================================================

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end

    //==========================================================================
    // Functional Coverage
    //==========================================================================

    covergroup cg_data_memory;

        cp_access_size : coverpoint access_size;

        cp_mem_read : coverpoint mem_read;

        cp_mem_write : coverpoint mem_write;

        cp_unsigned : coverpoint load_unsigned;

        cp_byte_offset : coverpoint addr[1:0];

        access_vs_offset : cross cp_access_size, cp_byte_offset;

        rw_vs_access : cross cp_mem_read,
                             cp_mem_write,
                             cp_access_size;

    endgroup

    cg_data_memory memory_cg = new();

    //==========================================================================
    // Immediate Assertions
    //==========================================================================

    always_comb begin

        if (!mem_read) begin

            assert (read_data == '0)
            else
                $error("[%0t] ERROR : read_data_o should be zero when mem_read_i is LOW.",
                       $time);

        end

    end

    //==========================================================================
    // Reference Model Functions
    //==========================================================================

    //----------------------------------------------------------------------
    // Update Golden Reference Memory
    //----------------------------------------------------------------------
    // Updates the byte-addressable reference memory after every successful
    // store transaction.
    //----------------------------------------------------------------------

    task automatic reference_store (
        input logic [XLEN-1:0]      address,
        input logic [XLEN-1:0]      data,
        input mem_access_size_t     size
    );

        unique case (size)

            BYTE_ACCESS: begin

                golden_mem[address] = data[7:0];

            end

            HALFWORD_ACCESS: begin

                golden_mem[address]     = data[7:0];
                golden_mem[address + 1] = data[15:8];

            end

            WORD_ACCESS: begin

                golden_mem[address]     = data[7:0];
                golden_mem[address + 1] = data[15:8];
                golden_mem[address + 2] = data[23:16];
                golden_mem[address + 3] = data[31:24];

            end

            default: begin

            end

        endcase

    endtask

    //----------------------------------------------------------------------
    // Expected Load Data
    //----------------------------------------------------------------------
    // Reads the golden reference memory and returns the expected value.
    //----------------------------------------------------------------------

    function automatic logic [XLEN-1:0] expected_load_data (

        input logic [XLEN-1:0]      address,
        input mem_access_size_t     size,
        input logic                 unsigned_load

    );

        logic [7:0]   byte_value;
        logic [15:0]  halfword_value;
        logic [31:0]  word_value;

        begin

            byte_value =
            golden_mem[address];

            halfword_value = {

                golden_mem[address + 1],
                golden_mem[address]

            };

            word_value = {

                golden_mem[address + 3],
                golden_mem[address + 2],
                golden_mem[address + 1],
                golden_mem[address]

            };

            unique case (size)

                BYTE_ACCESS: begin

                    if (unsigned_load)

                        expected_load_data =
                        {24'h0, byte_value};

                    else

                        expected_load_data =
                        {{24{byte_value[7]}}, byte_value};

                end

                HALFWORD_ACCESS: begin

                    if (unsigned_load)

                        expected_load_data =
                        {16'h0, halfword_value};

                    else

                        expected_load_data =
                        {{16{halfword_value[15]}},
                         halfword_value};

                end

                WORD_ACCESS: begin

                    expected_load_data =
                    word_value;

                end

                default: begin

                    expected_load_data =
                    '0;

                end

            endcase

        end

    endfunction

    //----------------------------------------------------------------------
    // Clear Golden Memory
    //----------------------------------------------------------------------
    // Used during initialization.
    //----------------------------------------------------------------------

    task automatic initialize_golden_memory();

        foreach (golden_mem[i]) begin

            golden_mem[i] = '0;

        end

    endtask

    //==========================================================================
    // Driver / Checker Tasks
    //==========================================================================

    //----------------------------------------------------------------------
    // Initialize DUT Inputs
    //----------------------------------------------------------------------

    task automatic initialize_inputs();

        mem_read        = 1'b0;
        mem_write       = 1'b0;

        addr            = '0;
        write_data      = '0;

        access_size     = WORD_ACCESS;
        load_unsigned   = 1'b0;

    endtask


    //----------------------------------------------------------------------
    // Memory Write Transaction
    //----------------------------------------------------------------------

    task automatic write_transaction(

        input logic [XLEN-1:0]      address,
        input logic [XLEN-1:0]      data,
        input mem_access_size_t     size

    );

        //--------------------------------------------------
        // Drive DUT
        //--------------------------------------------------

        @(negedge clk);

        mem_read      = 1'b0;
        mem_write     = 1'b1;

        addr          = address;
        write_data    = data;
        access_size   = size;

        //--------------------------------------------------
        // Write occurs on rising edge
        //--------------------------------------------------

        @(posedge clk);

        //--------------------------------------------------
        // Update Reference Model
        //--------------------------------------------------

        reference_store(
            address,
            data,
            size
        );

        //--------------------------------------------------
        // Return bus to idle
        //--------------------------------------------------

        @(negedge clk);

        mem_write = 1'b0;

    endtask


    //----------------------------------------------------------------------
    // Memory Read Transaction
    //----------------------------------------------------------------------

    task automatic read_transaction(

        input logic [XLEN-1:0]      address,
        input mem_access_size_t     size,
        input logic                 unsigned_load

    );

        @(negedge clk);

        mem_read        = 1'b1;
        mem_write       = 1'b0;

        addr            = address;
        access_size     = size;
        load_unsigned   = unsigned_load;

        #1;

        expected_data = expected_load_data(

            address,
            size,
            unsigned_load

        );

        check_result(expected_data);

        memory_cg.sample();

        @(negedge clk);

        mem_read = 1'b0;

    endtask


    //----------------------------------------------------------------------
    // Scoreboard Check
    //----------------------------------------------------------------------

    task automatic check_result(

        input logic [XLEN-1:0] expected

    );

        total_tests++;

        if (read_data === expected) begin

            passed_tests++;

        end
        else begin

            failed_tests++;

            $error(
                "[%0t] DATA MISMATCH\nExpected : %h\nReceived : %h",
                $time,
                expected,
                read_data
            );

        end

    endtask


    //----------------------------------------------------------------------
    // Display Memory (Debug Utility)
    //----------------------------------------------------------------------

    task automatic display_memory(

        input int start_addr,
        input int end_addr

    );

        int i;

        $display("\nGolden Memory Contents");

        for (i = start_addr; i <= end_addr; i++) begin

            $display(
                "Address %0d : %02h",
                i,
                golden_mem[i]
            );

        end

    endtask

    //==========================================================================
    // Test Sequence
    //==========================================================================

    initial begin

        //--------------------------------------------------------------
        // Initialize
        //--------------------------------------------------------------

        initialize_inputs();
        initialize_golden_memory();

        total_tests  = 0;
        passed_tests = 0;
        failed_tests = 0;

        $display("\n========================================");
        $display("Starting Data Memory Verification");
        $display("========================================");

        //----------------------------------------------------------------------
        // WORD ACCESS TESTS
        //----------------------------------------------------------------------

        $display("\n[WORD ACCESS TESTS]");

        // Write and Read Word
        write_transaction(
            32'h00000000,
            32'h12345678,
            WORD_ACCESS
        );

        read_transaction(
            32'h00000000,
            WORD_ACCESS,
            1'b0
        );

        // Another Word
        write_transaction(
            32'h00000004,
            32'hDEADBEEF,
            WORD_ACCESS
        );

        read_transaction(
            32'h00000004,
            WORD_ACCESS,
            1'b0
        );

        //----------------------------------------------------------------------
        // BYTE STORE TESTS
        //----------------------------------------------------------------------

        $display("\n[BYTE STORE TESTS]");

        write_transaction(
            32'h00000010,
            32'hAAAAAAAA,
            WORD_ACCESS
        );

        write_transaction(
            32'h00000011,
            32'h00000055,
            BYTE_ACCESS
        );

        read_transaction(
            32'h00000010,
            WORD_ACCESS,
            1'b0
        );

        //----------------------------------------------------------------------
        // HALFWORD STORE TESTS
        //----------------------------------------------------------------------

        $display("\n[HALFWORD STORE TESTS]");

        write_transaction(
            32'h00000020,
            32'hFFFFFFFF,
            WORD_ACCESS
        );

        write_transaction(
            32'h00000022,
            32'h00001234,
            HALFWORD_ACCESS
        );

        read_transaction(
            32'h00000020,
            WORD_ACCESS,
            1'b0
        );

        //----------------------------------------------------------------------
        // BYTE LOAD TESTS
        //----------------------------------------------------------------------

        $display("\n[BYTE LOAD TESTS]");

        write_transaction(
            32'h00000030,
            32'h80AA55FF,
            WORD_ACCESS
        );

        // Signed Byte
        read_transaction(
            32'h00000030,
            BYTE_ACCESS,
            1'b0
        );

        // Unsigned Byte
        read_transaction(
            32'h00000030,
            BYTE_ACCESS,
            1'b1
        );

        //----------------------------------------------------------------------
        // HALFWORD LOAD TESTS
        //----------------------------------------------------------------------

        $display("\n[HALFWORD LOAD TESTS]");

        write_transaction(
            32'h00000040,
            32'h8001ABCD,
            WORD_ACCESS
        );

        read_transaction(
            32'h00000040,
            HALFWORD_ACCESS,
            1'b0
        );

        read_transaction(
            32'h00000040,
            HALFWORD_ACCESS,
            1'b1
        );

        //----------------------------------------------------------------------
        // OVERWRITE TESTS
        //----------------------------------------------------------------------

        $display("\n[OVERWRITE TESTS]");

        write_transaction(
            32'h00000050,
            32'h11111111,
            WORD_ACCESS
        );

        write_transaction(
            32'h00000050,
            32'h22222222,
            WORD_ACCESS
        );

        read_transaction(
            32'h00000050,
            WORD_ACCESS,
            1'b0
        );

        //----------------------------------------------------------------------
        // BOUNDARY ADDRESS TESTS
        //----------------------------------------------------------------------

        $display("\n[BOUNDARY ADDRESS TESTS]");

        write_transaction(
            32'h00000000,
            32'hCAFEBABE,
            WORD_ACCESS
        );

        read_transaction(
            32'h00000000,
            WORD_ACCESS,
            1'b0
        );

        write_transaction(
            ((MEM_DEPTH * 4) - 4),
            32'hFACE1234,
            WORD_ACCESS
        );

        read_transaction(
            ((MEM_DEPTH * 4) - 4),
            WORD_ACCESS,
            1'b0
        );

        //----------------------------------------------------------------------
        // RANDOM TESTS
        //----------------------------------------------------------------------

        $display("\n[RANDOM TESTS]");

        logic [31:0] random_address;
        logic [31:0] random_data;
        logic        random_unsigned;

        repeat (NUM_RANDOM_TESTS) begin

            //--------------------------------------------------
            // Generate Random Access Type
            //--------------------------------------------------

            access_size = mem_access_size_t'($urandom_range(0, 2));

            //--------------------------------------------------
            // Generate Random Address
            //--------------------------------------------------

            random_address = $urandom_range(0, (MEM_DEPTH * 4) - 4);

            unique case (access_size)

                BYTE_ACCESS: begin
                    // Any address is valid
                end

                HALFWORD_ACCESS: begin
                    random_address[0] = 1'b0;
                end

                WORD_ACCESS: begin
                    random_address[1:0] = 2'b00;
                end

            endcase

            //--------------------------------------------------
            // Random Data
            //--------------------------------------------------

            random_data = $urandom;

            //--------------------------------------------------
            // Random Signed / Unsigned
            //--------------------------------------------------

            random_unsigned = $urandom_range(0,1);

            //--------------------------------------------------
            // Write
            //--------------------------------------------------

            write_transaction(
                random_address,
                random_data,
                access_size
            );

            //--------------------------------------------------
            // Read Back
            //--------------------------------------------------

            read_transaction(
                random_address,
                access_size,
                random_unsigned
            );

        end

        //----------------------------------------------------------------------
        // Final Report
        //----------------------------------------------------------------------

        $display("\n");
        $display("======================================================");
        $display("            DATA MEMORY VERIFICATION REPORT");
        $display("======================================================");

        $display("Total Tests  : %0d", total_tests);
        $display("Passed Tests : %0d", passed_tests);
        $display("Failed Tests : %0d", failed_tests);

        if (failed_tests == 0) begin

            $display("\n");
            $display("**********************************************");
            $display("*                                            *");
            $display("*       ALL TESTS PASSED SUCCESSFULLY        *");
            $display("*                                            *");
            $display("**********************************************");

        end
        else begin

            $display("\n");
            $display("**********************************************");
            $display("*                                            *");
            $display("*            TEST FAILED                     *");
            $display("*                                            *");
            $display("**********************************************");

        end

        $display("======================================================");

        $finish;

    end

endmodule

