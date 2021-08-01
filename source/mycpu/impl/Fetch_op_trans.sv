`include "common.svh"
`include "mycpu/mycpu.svh"

module Fetch_op_trans (
    input word_t instr,
    output op_t op
);

always_comb begin
    unique case (instr[31:26])
        6'b000000: begin // R-type
            unique case (instr[5:0])
                6'b000000: begin
                    if (instr[15:11] == 0)
                        op = NOP;
                    else
                        op = SLL;
                end
                6'b000010: op = SRL;
                6'b000011: op = SRA;
                6'b000100: op = SLLV;
                6'b000110: op = SRLV;
                6'b000111: op = SRAV;
                6'b001000: op = JR;
                6'b001001: op = JALR;
                6'b001100: op = SYSCALL;
                6'b001101: op = BREAK;
                6'b010000: op = MFHI;
                6'b010010: op = MFLO;
                6'b010001: op = MTHI;
                6'b010011: op = MTLO;
                6'b011000: op = MULT;
                6'b011001: op = MULTU;
                6'b011010: op = DIV;
                6'b011011: op = DIVU;
                6'b100000: op = ADD;
                6'b100001: op = ADDU;
                6'b100010: op = SUB;
                6'b100011: op = SUBU;
                6'b100100: op = AND;
                6'b100101: op = OR;
                6'b100110: op = XOR;
                6'b100111: op = NOR;
                6'b101010: op = SLT;
                6'b101011: op = SLTU;
                default:
                    op = DECODE_ERROR;
            endcase
        end
        6'b000001: begin
            unique case (instr[20:16])
                5'b00000: op = BLTZ;
                5'b00001: op = BGEZ;
                5'b10000: op = BLTZAL;
                5'b10001: op = BGEZAL;
                default:
                    op = DECODE_ERROR;
            endcase
        end
        6'b000010: op = J;
        6'b000011: op = JAL;
        6'b000100: op = BEQ;
        6'b000101: op = BNE;
        6'b000110: op = BLEZ;
        6'b000111: op = BGTZ;
        6'b001000: op = ADDI;
        6'b001001: op = ADDIU;
        6'b001010: op = SLTI;
        6'b001011: op = SLTIU;
        6'b001100: op = ANDI;
        6'b001101: op = ORI;
        6'b001110: op = XORI;
        6'b001111: op = LUI;
        6'b010000: begin
            if (instr[25:21] == 5'b0)
                op = MFC0;
            else if (instr[25:21] == 5'b00100)
                op = MTC0;
            else if (instr[25] == 1'b1 && instr[24:6] == 19'b0)
                op = ERET;
            else
                op = DECODE_ERROR;
        end
        6'b011100: begin 
            if (instr[5:0] == 6'b000010 && instr[10:6] == 5'b00000)
                // if use MUL
                // op = MUL;
                // if don't use MUL
                op = NOP;
            else
                op = DECODE_ERROR;
        end
        6'b100000: op = LB;
        6'b100001: op = LH;
        6'b100011: op = LW;
        6'b100100: op = LBU;
        6'b100101: op = LHU;
        6'b101000: op = SB;
        6'b101001: op = SH;
        6'b101011: op = SW;
        default:
            op = DECODE_ERROR;
    endcase
end

endmodule
