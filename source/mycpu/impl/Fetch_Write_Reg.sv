`include "common.svh"
`include "mycpu/mycpu.svh"

module Fetch_Write_Reg (
    input op_t op,
    input creg_addr_t rt, rd,
    output write_reg_t write_reg
);

    always_comb begin
        write_reg = '0;
        unique case (op)
            // Op 0 R-Type
            SLL, SRL, SRA, SLLV, SRLV, SRAV, JALR: begin
                write_reg.valid = 1;
                write_reg.src = SRC_ALU;
                write_reg.value = 32'h0;
                write_reg.dst = rd;
            end
            MFHI, MFLO: begin
                write_reg.valid = 1;
                write_reg.src = SRC_NOP;
                write_reg.value = 32'h0;
                write_reg.dst = rd;
            end
            MTHI, MTLO, MULT, MULTU, DIV, DIVU: begin
                write_reg = '0;
            end
            ADD, ADDU, SUB, SUBU, AND, OR, XOR, NOR, SLT, SLTU: begin
                write_reg.valid = 1;
                write_reg.src = SRC_ALU;
                write_reg.value = 32'h0;
                write_reg.dst = rd;
            end
            // Op 1
            BLTZ, BGEZ: begin
                write_reg = '0;
            end
            BLTZAL, BGEZAL: begin
                write_reg.valid = 1;
                write_reg.src = SRC_ALU;
                write_reg.value = 32'h0;
                write_reg.dst = 5'h1f;
            end
            // Others
            J: begin
                write_reg = '0;
            end
            JAL: begin
                write_reg.valid = 1;
                write_reg.src = SRC_ALU;
                write_reg.value = 32'h0;
                write_reg.dst = 5'h1f;
            end
            BEQ, BNE, BLEZ, BGTZ: begin
                write_reg = '0;
            end
            ADDI, ADDIU, SLTI, SLTIU, ANDI, ORI, XORI, LUI: begin
                write_reg.valid = 1;
                write_reg.src = SRC_ALU;
                write_reg.value = 32'h0;
                write_reg.dst = rt;
            end
            MFC0: begin
                write_reg.valid = 1;
                write_reg.src = SRC_NOP;
                write_reg.value = 32'h0;
                write_reg.dst = rt;
            end
            MTC0: begin
                write_reg.valid = 1;
                write_reg.src = SRC_NOP;
                write_reg.value = 32'h0;
                write_reg.dst = rd;
            end
            LB, LH, LW, LBU, LHU: begin
                write_reg.valid = 1;
                write_reg.src = SRC_MEM;
                write_reg.value = 32'h0;
                write_reg.dst = rt;
            end
            SB, SH, SW: begin
                write_reg = '0;
            end
            MUL: begin
                write_reg.valid = 1;
                write_reg.src = SRC_ALU;
                write_reg.value = 32'h0;
                write_reg.dst = rd;
            end
            default: begin
                write_reg = '0;
            end
        endcase
    end

endmodule
