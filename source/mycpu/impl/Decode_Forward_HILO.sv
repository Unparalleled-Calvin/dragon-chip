`include "common.svh"
`include "mycpu/mycpu.svh"

module Decode_Forward_HILO(
    input write_hilo_t write_hilo[5:0],
    input word_t data_hi, data_lo,
    output word_t vhi, vlo
);

always_comb begin
    vhi = data_hi;
    for (int i = 0; i < 6; i++)
        if (write_hilo[i].valid_hi) begin
            vhi = write_hilo[i].hi;
            break;
        end
    
    vlo = data_lo;
    for (int i = 0; i < 6; i++)
        if (write_hilo[i].valid_lo) begin
            vlo = write_hilo[i].lo;
            break;
        end
end

endmodule
