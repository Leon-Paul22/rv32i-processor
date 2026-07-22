import rv32i_pkg::*;

module data_memory #(
    parameter int XLEN      = 32,
    parameter int MEM_DEPTH = 1024
)(
    input  logic                     clk_i,

    // Memory Control
    input  logic                     mem_read_i,
    input  logic                     mem_write_i,

    // Memory Address (Byte Address)
    input  logic [XLEN-1:0]          addr_i,

    // Store Data
    input  logic [XLEN-1:0]          write_data_i,

    // Access Information
    input  mem_access_size_t         access_size_i,
    input  logic                     load_unsigned_i,

    // Load Data
    output logic [XLEN-1:0]          read_data_o
);

    //----------------------------------------------------------------------
    // Temporary LSU functionality
    // The following logic will migrate into a dedicated Load Store Unit
    // during the pipelined processor implementation.
    //----------------------------------------------------------------------
    //
    // - Byte/Halfword extraction
    // - Sign extension
    // - Zero extension
    // - Partial write generation
    //
    //----------------------------------------------------------------------

    localparam int WORD_ADDR_WIDTH = $clog2(MEM_DEPTH);

    logic [XLEN-1:0] mem [0:MEM_DEPTH-1];

    logic [WORD_ADDR_WIDTH-1:0] word_addr;
    logic [1:0]                 byte_offset;

    logic [XLEN-1:0]            word_data;

    //------------------------------------------------------------
    // Address Decode
    //------------------------------------------------------------

    assign word_addr   = addr_i[WORD_ADDR_WIDTH+1:2];
    assign byte_offset = addr_i[1:0];

    //------------------------------------------------------------
    // Read selected word
    //------------------------------------------------------------

    assign word_data = mem[word_addr];

    //------------------------------------------------------------
    // Combinational Read Logic
    //------------------------------------------------------------

    always_comb begin

        read_data_o = '0;

        if (mem_read_i) begin

            unique case (access_size_i)

                BYTE_ACCESS: begin

                    unique case (byte_offset)

                        2'b00: read_data_o = load_unsigned_i ?
                                            {{24{1'b0}}, word_data[7:0]} :
                                            {{24{word_data[7]}}, word_data[7:0]};

                        2'b01: read_data_o = load_unsigned_i ?
                                            {{24{1'b0}}, word_data[15:8]} :
                                            {{24{word_data[15]}}, word_data[15:8]};

                        2'b10: read_data_o = load_unsigned_i ?
                                            {{24{1'b0}}, word_data[23:16]} :
                                            {{24{word_data[23]}}, word_data[23:16]};

                        2'b11: read_data_o = load_unsigned_i ?
                                            {{24{1'b0}}, word_data[31:24]} :
                                            {{24{word_data[31]}}, word_data[31:24]};

                    endcase

                end

                HALFWORD_ACCESS: begin

                    unique case (byte_offset)

                        2'b00: read_data_o = load_unsigned_i ?
                                            {{16{1'b0}}, word_data[15:0]} :
                                            {{16{word_data[15]}}, word_data[15:0]};

                        2'b10: read_data_o = load_unsigned_i ?
                                            {{16{1'b0}}, word_data[31:16]} :
                                            {{16{word_data[31]}}, word_data[31:16]};

                        default: read_data_o = '0; // Misaligned (future exception)

                    endcase

                end

                WORD_ACCESS: begin

                    read_data_o = word_data;

                end

                default: begin

                    read_data_o = '0;

                end

            endcase

        end

    end

    //------------------------------------------------------------
    // Synchronous Write Logic
    //------------------------------------------------------------

    always_ff @(posedge clk_i) begin

        if (mem_write_i) begin

            unique case (access_size_i)

                BYTE_ACCESS: begin

                    unique case (byte_offset)

                        2'b00: mem[word_addr][7:0]   <= write_data_i[7:0];
                        2'b01: mem[word_addr][15:8]  <= write_data_i[7:0];
                        2'b10: mem[word_addr][23:16] <= write_data_i[7:0];
                        2'b11: mem[word_addr][31:24] <= write_data_i[7:0];

                    endcase

                end

                HALFWORD_ACCESS: begin

                    unique case (byte_offset)

                        2'b00: mem[word_addr][15:0]  <= write_data_i[15:0];
                        2'b10: mem[word_addr][31:16] <= write_data_i[15:0];

                        default: ;

                    endcase

                end

                WORD_ACCESS: begin

                    mem[word_addr] <= write_data_i;

                end

                default: ;

            endcase

        end

    end

endmodule