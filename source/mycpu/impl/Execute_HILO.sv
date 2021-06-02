`include "common.svh"
`include "mycpu/mycpu.svh"

module Execute_HILO (
    input op_t op,
    input word_t a, b,
    input word_t vhi, vlo,
    input i64 mult_c, div_c,
    output word_t hi, lo
);

    i64 mult_c_neg;
    assign mult_c_neg = -$signed(mult_c);

    always_comb begin
        unique case (op)
            MULTU: begin
                hi = mult_c[63:32];
                lo = mult_c[31:0];
            end
            MULT: begin
                if (a[31] == b[31]) begin // a>=0&&b>=0 || a<0&&b<0
                    hi = mult_c[63:32];
                    lo = mult_c[31:0];
                end
                else begin
                    hi = mult_c_neg[63:32];
                    lo = mult_c_neg[31:0];
                end
            end
            MADDU: begin
                {hi, lo} = {vhi, vlo} + mult_c;
            end
            MADD: begin
                if (a[31] == b[31]) begin
                    {hi, lo} = {vhi, vlo} + mult_c;
                end
                else begin
                    {hi, lo} = {vhi, vlo} + mult_c_neg;
                end
            end
            MSUBU: begin
                {hi, lo} = {vhi, vlo} - mult_c;
            end
            MSUB: begin
                if (a[31] == b[31]) begin
                    {hi, lo} = {vhi, vlo} - mult_c;
                end
                else begin
                    {hi, lo} = {vhi, vlo} - mult_c_neg;
                end
            end
            decodeContext.op == MSUB || decodeContext.op == MSUBU
            DIVU: begin
                hi = div_c[63:32];
                lo = div_c[31:0];
            end
            DIV: begin
                unique case ({a[31], b[31]})
                    2'b00: begin
                        hi = div_c[63:32];
                        lo = div_c[31:0];
                    end
                    2'b01: begin
                        hi = div_c[63:32];
                        lo = -$signed(div_c[31:0]);
                    end
                    2'b10: begin
                        hi = -$signed(div_c[63:32]);
                        lo = -$signed(div_c[31:0]);
                    end
                    2'b11: begin
                        hi = -$signed(div_c[63:32]);
                        lo = div_c[31:0];
                    end
                endcase
            end
            default: begin
                hi = 32'h0;
                lo = 32'h0;
            end
        endcase
    end

endmodule
