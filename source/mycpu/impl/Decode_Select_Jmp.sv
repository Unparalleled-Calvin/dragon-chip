`include "common.svh"
`include "mycpu/mycpu.svh"

module Decode_Select_Jmp (
    input op_t op,
    input addr_t pc_src, 
    input vars_t vars,

    output jmp_pack_t jmp,
    output logic jmp_delayed
);

always_comb begin
    jmp.stat = J_NOP;
    jmp.pc_src = pc_src;
    jmp.pc_dst = 32'h0;
    jmp_delayed = 0;

    unique case (op)
        JR, JALR: begin
            jmp.stat = J_REG;
            jmp.pc_dst = vars.vs;
            jmp_delayed = 1;
        end
        BLTZ, BLTZAL: begin
            if ($signed(vars.vs) < $signed(32'h0)) begin
                jmp.stat = J_REL;
                jmp.pc_dst = pc_src + (vars.vi << 2) + 4;
            end
            jmp_delayed = 1;
        end
        BGEZ, BGEZAL: begin
            if ($signed(vars.vs) >= $signed(32'h0)) begin
                jmp.stat = J_REL;
                jmp.pc_dst = pc_src + (vars.vi << 2) + 4;
            end
            jmp_delayed = 1;
        end

        J, JAL: begin
            jmp.stat = J_DIR;
            jmp.pc_dst = vars.vj;
            jmp_delayed = 1;
        end
        BEQ: begin 
            if (vars.vs == vars.vt) begin
                jmp.stat = J_REL;
                jmp.pc_dst = pc_src + (vars.vi << 2) + 4;
            end
            jmp_delayed = 1;
        end
        BNE: begin
            if (vars.vs != vars.vt) begin
                jmp.stat = J_REL;
                jmp.pc_dst = pc_src + (vars.vi << 2) + 4;
            end
            jmp_delayed = 1;
        end
        BLEZ: begin
            if ($signed(vars.vs) <= $signed(32'h0)) begin
                jmp.stat = J_REL;
                jmp.pc_dst = pc_src + (vars.vi << 2) + 4;
            end
            jmp_delayed = 1;
        end
        BGTZ: begin
            if ($signed(vars.vs) > $signed(32'h0)) begin
                jmp.stat = J_REL;
                jmp.pc_dst = pc_src + (vars.vi << 2) + 4;
            end
            jmp_delayed = 1;
        end
        default: begin
        end
    endcase
end

endmodule
