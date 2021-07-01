`include "common.svh"
`include "mycpu/mycpu.svh"

module Decode_Write_HILO (
    input op_t op,
    input word_t vs,
    input write_hilo_t Write_hilo,
    output write_hilo_t write_hilo
);

    always_comb begin
        write_hilo = Write_hilo;
        unique case (op)
            MTHI: write_hilo.hi = vs;
            MTLO: write_hilo.lo = vs;
            default: begin end
        endcase
    end

endmodule
