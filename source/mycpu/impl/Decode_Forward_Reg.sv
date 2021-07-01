`include "common.svh"
`include "mycpu/mycpu.svh"

module Decode_Forward_Reg(
    input write_reg_t write_reg[5:0],
    input creg_addr_t src,
    input word_t data_src,
	
    output word_t vr
);

always_comb begin
    if (src != 5'b0) begin
        vr = data_src;
        for (int i = 0; i < 6; i++)
            if (write_reg[i].valid && write_reg[i].dst == src) begin
                vr = write_reg[i].value;
                break;
            end
    end
    else
        vr = 32'b0;
end

endmodule
