`timescale 1ns/1ps

module tb_immediate_generator();

    //------------------------------------------------------------
    // Parameters
    //------------------------------------------------------------

    localparam int XLEN = 32;
    localparam int NUM_RANDOM_TESTS = 100;

    //------------------------------------------------------------
    // Boundary Test Values
    //------------------------------------------------------------

    localparam logic [11:0] IMM12_ZERO    = 12'h000;
    localparam logic [11:0] IMM12_ONE     = 12'h001;
    localparam logic [11:0] IMM12_POS_MAX = 12'h7FF;
    localparam logic [11:0] IMM12_NEG_MIN = 12'h800;
    localparam logic [11:0] IMM12_NEG_ONE = 12'hFFF;

    localparam logic [12:0] IMM13_ZERO    = 13'h0000;
    localparam logic [12:0] IMM13_TWO     = 13'h0002;
    localparam logic [12:0] IMM13_POS_MAX = 13'h0FFE;
    localparam logic [12:0] IMM13_NEG_MIN = 13'h1000;
    localparam logic [12:0] IMM13_NEG_TWO = 13'h1FFE;

    localparam logic [19:0] IMM20_ZERO    = 20'h00000;
    localparam logic [19:0] IMM20_ONE     = 20'h00001;
    localparam logic [19:0] IMM20_POS_MAX = 20'h7FFFF;
    localparam logic [19:0] IMM20_NEG_MIN = 20'h80000;
    localparam logic [19:0] IMM20_NEG_ONE = 20'hFFFFF;

    localparam logic [20:0] IMM21_ZERO    = 21'h00000;
    localparam logic [20:0] IMM21_TWO     = 21'h00002;
    localparam logic [20:0] IMM21_POS_MAX = 21'h0FFFFE;
    localparam logic [20:0] IMM21_NEG_MIN = 21'h100000;
    localparam logic [20:0] IMM21_NEG_TWO = 21'h1FFFFE;

    logic [31:0] instruction_i;
    logic [XLEN-1:0] immediate_o;
    logic [XLEN-1:0] expected;

    int total_tests, passed_tests, failed_tests;

    logic [11:0] imm12_tests [5] = '{IMM12_ZERO,IMM12_ONE,IMM12_POS_MAX,IMM12_NEG_MIN,IMM12_NEG_ONE};
    logic [12:0] imm13_tests [5] = '{IMM13_ZERO,IMM13_TWO,IMM13_POS_MAX,IMM13_NEG_MIN,IMM13_NEG_TWO};
    logic [19:0] imm20_tests [5] = '{IMM20_ZERO,IMM20_ONE,IMM20_POS_MAX,IMM20_NEG_MIN,IMM20_NEG_ONE};
    logic [20:0] imm21_tests [5] = '{IMM21_ZERO,IMM21_TWO,IMM21_POS_MAX,IMM21_NEG_MIN,IMM21_NEG_TWO};

    logic [6:0] i_opcodes [3] = '{7'b0010011,7'b0000011,7'b1100111};
    logic [6:0] u_opcodes [2] = '{7'b0110111,7'b0010111};

    immediate_generator #(.XLEN(XLEN)) dut(
        .instruction_i(instruction_i),
        .immediate_o(immediate_o)
    );

    function logic [31:0] build_r_instruction(input logic [6:0] funct7,input logic [4:0] rs2,input logic [4:0] rs1,input logic [2:0] funct3,input logic [4:0] rd,input logic [6:0] opcode);
        return {funct7,rs2,rs1,funct3,rd,opcode};
    endfunction

    function logic [31:0] build_i_instruction(input logic [11:0] imm,input logic [4:0] rs1,input logic [2:0] funct3,input logic [4:0] rd,input logic [6:0] opcode);
        return {imm,rs1,funct3,rd,opcode};
    endfunction

    function logic [31:0] build_s_instruction(input logic [11:0] imm,input logic [4:0] rs2,input logic [4:0] rs1,input logic [2:0] funct3,input logic [6:0] opcode);
        return {imm[11:5],rs2,rs1,funct3,imm[4:0],opcode};
    endfunction

    function logic [31:0] build_b_instruction(input logic [12:0] imm,input logic [4:0] rs2,input logic [4:0] rs1,input logic [2:0] funct3,input logic [6:0] opcode);
        return {imm[12],imm[10:5],rs2,rs1,funct3,imm[4:1],imm[11],opcode};
    endfunction

    function logic [31:0] build_u_instruction(input logic [19:0] imm,input logic [4:0] rd,input logic [6:0] opcode);
        return {imm,rd,opcode};
    endfunction

    function logic [31:0] build_j_instruction(input logic [20:0] imm,input logic [4:0] rd,input logic [6:0] opcode);
        return {imm[20],imm[10:1],imm[11],imm[19:12],rd,opcode};
    endfunction

    function logic [XLEN-1:0] expected_immediate(input logic [31:0] instruction);
        logic [6:0] opcode;
        logic [31:0] imm;
        opcode=instruction[6:0];
        imm='0;
        case(opcode)
            7'b0110011: imm='0;
            7'b0010011,7'b0000011,7'b1100111: begin
                imm[11:0]=instruction[31:20];
                imm[31:12]={20{instruction[31]}};
            end
            7'b0100011: begin
                imm[11:5]=instruction[31:25];
                imm[4:0]=instruction[11:7];
                imm[31:12]={20{instruction[31]}};
            end
            7'b1100011: begin
                imm[12]=instruction[31];
                imm[11]=instruction[7];
                imm[10:5]=instruction[30:25];
                imm[4:1]=instruction[11:8];
                imm[0]=1'b0;
                imm[31:13]={19{instruction[31]}};
            end
            7'b0110111,7'b0010111: begin
                imm[31:12]=instruction[31:12];
                imm[11:0]=12'b0;
            end
            7'b1101111: begin
                imm[20]=instruction[31];
                imm[19:12]=instruction[19:12];
                imm[11]=instruction[20];
                imm[10:1]=instruction[30:21];
                imm[0]=1'b0;
                imm[31:21]={11{instruction[31]}};
            end
            default: imm='0;
        endcase
        return imm;
    endfunction

    task run_test(input logic [31:0] instruction);
    begin
        instruction_i=instruction;
        #1;
        expected=expected_immediate(instruction);
        total_tests++;
        assert(immediate_o===expected)
            passed_tests++;
        else begin
            failed_tests++;
            $display("FAIL Instr=%h Exp=%h Got=%h",instruction,expected,immediate_o);
            return;
        end
    end
    endtask

    initial begin
        total_tests=0; passed_tests=0; failed_tests=0;

        run_test(build_r_instruction(7'b0000000,5'd2,5'd1,3'b000,5'd3,7'b0110011));
        run_test(build_r_instruction(7'b0100000,5'd31,5'd31,3'b101,5'd31,7'b0110011));

        foreach(i_opcodes[op])
            foreach(imm12_tests[idx])
                run_test(build_i_instruction(imm12_tests[idx],5'd1,3'b000,5'd2,i_opcodes[op]));

        foreach(imm12_tests[idx])
            run_test(build_s_instruction(imm12_tests[idx],5'd2,5'd1,3'b010,7'b0100011));

        foreach(imm13_tests[idx])
            run_test(build_b_instruction(imm13_tests[idx],5'd2,5'd1,3'b000,7'b1100011));

        foreach(u_opcodes[op])
            foreach(imm20_tests[idx])
                run_test(build_u_instruction(imm20_tests[idx],5'd1,u_opcodes[op]));

        foreach(imm21_tests[idx])
            run_test(build_j_instruction(imm21_tests[idx],5'd1,7'b1101111));

        run_test(32'hFFFFFFFF);
        run_test(32'h00000000);
        run_test(32'h12345678);

        repeat(NUM_RANDOM_TESTS) begin
            instruction_i=$urandom;
            case($urandom_range(0,8))
                0: instruction_i[6:0]=7'b0110011;
                1: instruction_i[6:0]=7'b0010011;
                2: instruction_i[6:0]=7'b0000011;
                3: instruction_i[6:0]=7'b1100111;
                4: instruction_i[6:0]=7'b0100011;
                5: instruction_i[6:0]=7'b1100011;
                6: instruction_i[6:0]=7'b0110111;
                7: instruction_i[6:0]=7'b0010111;
                8: instruction_i[6:0]=7'b1101111;
            endcase
            run_test(instruction_i);
        end

        $display("========================================");
        $display("Immediate Generator Test Summary");
        $display("Total Tests : %0d",total_tests);
        $display("Passed      : %0d",passed_tests);
        $display("Failed      : %0d",failed_tests);
        $display("========================================");

        $finish;
    end

endmodule
