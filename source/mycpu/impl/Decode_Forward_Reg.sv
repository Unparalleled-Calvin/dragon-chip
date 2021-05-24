`include "common.svh"
`include "mycpu/mycpu.svh"

module Decode_Forward_Reg(
    input write_reg_t e, m, w,
    input creg_addr_t src,
    input word_t data_src,
	
    output word_t vr
);

always_comb begin
    if (src != 5'b0) begin
        if (e.valid && e.src != SRC_MEM && e.dst == src)
            vr = e.value;
        else if (m.valid && m.dst == src)
            vr = m.value;
        else if (w.valid && w.dst == src)
            vr = w.value;
        else
            vr = data_src;
    end
    else
        vr = 32'b0;
end

endmodule
