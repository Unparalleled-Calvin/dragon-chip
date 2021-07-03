`include "common.svh"
`include "mycpu/mycpu.svh"

module Fetch_Select_Jmp (
    input op_t op,

    output jmp_pack_t jmp
);

always_comb begin
    unique case (op)
        JR, JALR, BLTZ, BLTZAL, BGEZ, BGEZAL, J, JAL, BEQ, BNE, BLEZ, BGTZ: begin
            jmp.valid = 1;
            jmp.en = 0;
            jmp.pc_dst = '0;
        end
        default: begin
            jmp = '0;
        end
    endcase
end

endmodule
