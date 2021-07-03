`include "common.svh"
`include "mycpu/mycpu.svh"

module Decode_Write_Reg (
    input op_t op,
    input cp0_t cp0,
    input word_t vt, vhi, vlo,
    input creg_addr_t rd,
    input write_reg_t Write_reg,
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
        write_reg = Write_reg;
        unique case (op)
            // Op 0 R-Type
            MFHI: write_reg.value = vhi;
            MFLO: write_reg.value = vlo;
            MFC0: write_reg.value = cp0_v_old;
            MTC0: write_reg.value = cp0_v_updated;
            default: begin end
        endcase
    end

endmodule
