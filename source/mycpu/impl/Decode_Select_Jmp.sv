`include "common.svh"
`include "mycpu/mycpu.svh"

module Decode_Select_Jmp (
    input op_t op,
    input addr_t pc_src, 
    input word_t vs, vt, vi, vj,
    input jmp_pack_t Jmp,
    output jmp_pack_t jmp
);

always_comb begin
    jmp = Jmp;

    unique case (op)
        JR, JALR: begin
            jmp.en  = 1;
            jmp.pc_dst = vs;
        end
        BLTZ, BLTZAL: begin
            if ($signed(vs) < $signed(32'h0)) begin
                jmp.en  = 1;
                jmp.pc_dst = pc_src + (vi << 2) + 4;
            end
            else begin
                jmp.en  = 0;
                jmp.pc_dst = '0;
            end
        end
        BGEZ, BGEZAL: begin
            if ($signed(vs) >= $signed(32'h0)) begin
                jmp.en  = 1;
                jmp.pc_dst = pc_src + (vi << 2) + 4;
            end
            else begin
                jmp.en  = 0;
                jmp.pc_dst = '0;
            end
        end

        J, JAL: begin
            jmp.en  = 1;
            jmp.pc_dst = vj;
        end
        BEQ: begin 
            if (vs == vt) begin
                jmp.en  = 1;
                jmp.pc_dst = pc_src + (vi << 2) + 4;
            end
            else begin
                jmp.en  = 0;
                jmp.pc_dst = '0;
            end
        end
        BNE: begin
            if (vs != vt) begin
                jmp.en  = 1;
                jmp.pc_dst = pc_src + (vi << 2) + 4;
            end
            else begin
                jmp.en  = 0;
                jmp.pc_dst = '0;
            end
        end
        BLEZ: begin
            if ($signed(vs) <= $signed(32'h0)) begin
                jmp.en  = 1;
                jmp.pc_dst = pc_src + (vi << 2) + 4;
            end
            else begin
                jmp.en  = 0;
                jmp.pc_dst = '0;
            end
        end
        BGTZ: begin
            if ($signed(vs) > $signed(32'h0)) begin
                jmp.en  = 1;
                jmp.pc_dst = pc_src + (vi << 2) + 4;
            end
            else begin
                jmp.en  = 0;
                jmp.pc_dst = '0;
            end
        end
        default: begin
        end
    endcase
end

endmodule
