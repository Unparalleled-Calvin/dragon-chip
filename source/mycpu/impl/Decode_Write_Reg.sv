`include "common.svh"
`include "mycpu/mycpu.svh"

module Decode_Write_Reg (
    input op_t op,
    input word_t vt, vhi, vlo,
    input creg_addr_t rt, rd,
    input cp0_t cp0,
    output write_reg_t write_reg
);
    word_t cp0_v_old, cp0_v_new, cp0_v_updated, cp0_mask;

    always_comb begin
        unique case (rd)
            5'd8:  begin cp0_v_old = cp0.BadVAddr; cp0_mask = CP0_MASK.BadVAddr; end
            5'd9:  begin cp0_v_old = cp0.Count; cp0_mask = CP0_MASK.Count; end
            5'd11: begin cp0_v_old = cp0.Compare; cp0_mask = CP0_MASK.Compare; end
            5'd12: begin cp0_v_old = cp0.Status; cp0_mask = CP0_MASK.Status; end
            5'd13: begin cp0_v_old = cp0.Cause; cp0_mask = CP0_MASK.Cause; end
            5'd14: begin cp0_v_old = cp0.EPC; cp0_mask = CP0_MASK.EPC; end
            5'd30: begin cp0_v_old = cp0.ErrorEPC; cp0_mask = CP0_MASK.ErrorEPC; end
            default: begin cp0_v_old = 32'h0; cp0_mask = '0; end // TODO ERROR
        endcase
        cp0_v_new = vt;
        cp0_v_updated = (cp0_v_old & ~cp0_mask) | (cp0_v_new & cp0_mask);
    end
    
    always_comb begin
        write_reg = '0;
        unique case (op)
            // Op 0 R-Type
            SLL, SRL, SRA, SLLV, SRLV, SRAV: begin
                write_reg.valid = 1;
                write_reg.src = SRC_ALU;
                write_reg.value = 32'h0;
                write_reg.dst = rd;
            end
            JALR: begin
                write_reg.valid = 1;
                write_reg.src = SRC_ALU;
                write_reg.value = 32'h0;
                write_reg.dst = rd;
            end
            MFHI: begin
                write_reg.valid = 1;
                write_reg.src = SRC_NOP;
                write_reg.value = vhi;
                write_reg.dst = rd;
            end
            MFLO: begin
                write_reg.valid = 1;
                write_reg.src = SRC_NOP;
                write_reg.value = vlo;
                write_reg.dst = rd;
            end
            MTHI, MTLO: begin
                write_reg.valid = 0; //1;
                write_reg.src = SRC_NOP;
                write_reg.value = 32'h0;
                write_reg.dst = 5'h0; //rd;
            end
            MULT, MULTU, DIV, DIVU: begin
                write_reg.valid = 0; //1;
                write_reg.src = SRC_ALU;
                write_reg.value = 32'h0;
                write_reg.dst = 5'h0; //rd;
            end
            ADD, ADDU, SUB, SUBU, AND, OR, XOR, NOR, SLT, SLTU: begin
                write_reg.valid = 1;
                write_reg.src = SRC_ALU;
                write_reg.value = 32'h0;
                write_reg.dst = rd;
            end
            // Op 1
            BLTZ, BGEZ: begin
                write_reg.valid = 0;
                write_reg.src = SRC_NOP;
                write_reg.value = 32'h0;
                write_reg.dst = 5'h0;
            end
            BLTZAL, BGEZAL: begin
                write_reg.valid = 1;
                write_reg.src = SRC_ALU;
                write_reg.value = 32'h0;
                write_reg.dst = 5'h1f;
            end
            // Others
            J: begin
                write_reg.valid = 0;
                write_reg.src = SRC_NOP;
                write_reg.value = 32'h0;
                write_reg.dst = 5'h0;
            end
            JAL: begin
                write_reg.valid = 1;
                write_reg.src = SRC_ALU;
                write_reg.value = 32'h0;
                write_reg.dst = 5'h1f;
            end
            BEQ, BNE, BLEZ, BGTZ: begin
                write_reg.valid = 0;
                write_reg.src = SRC_NOP;
                write_reg.value = 32'h0;
                write_reg.dst = 5'h0;
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
                write_reg.value = cp0_v_old;
                write_reg.dst = rt;
            end
            MTC0: begin
                write_reg.valid = 1;
                write_reg.src = SRC_NOP;
                write_reg.value = cp0_v_updated;
                write_reg.dst = rd;
            end
            LB, LH, LW, LBU, LHU: begin
                write_reg.valid = 1;
                write_reg.src = SRC_MEM;
                write_reg.value = 32'h0;
                write_reg.dst = rt;
            end
            SB, SH, SW: begin
                write_reg.valid = 0;
                write_reg.src = SRC_NOP;
                write_reg.value = 32'h0;
                write_reg.dst = 5'h0;
            end
            default: begin
                write_reg = '0;
            end
        endcase
    end

endmodule
