`include "common.svh"
`include "mycpu/mycpu.svh"

module Decode_Write_HILO (
    input op_t op,
    input word_t vs,
    output write_hilo_t write_hilo
);

    always_comb begin
        unique case (op)
            MTHI: begin
                write_hilo.valid_hi = 1'b1;
                write_hilo.valid_lo = 1'b0;
                write_hilo.hi = vs;
                write_hilo.lo = 32'b0;
            end
            MTLO: begin
                write_hilo.valid_hi = 1'b0;
                write_hilo.valid_lo = 1'b1;
                write_hilo.hi = 32'b0;
                write_hilo.lo = vs;
            end
            MULT, MULTU, DIV, DIVU: begin
                write_hilo.valid_hi = 1'b1;
                write_hilo.valid_lo = 1'b1;
                write_hilo.hi = 32'b0;
                write_hilo.lo = 32'b0;
            end
            // Others
            default: begin
                write_hilo = '0;
            end
        endcase
    end

endmodule
