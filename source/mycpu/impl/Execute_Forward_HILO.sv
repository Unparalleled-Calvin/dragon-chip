`include "common.svh"
`include "mycpu/mycpu.svh"

module Execute_Forward_HILO(
    input write_hilo_t m, w,
    input word_t data_hi, data_lo,
    output word_t vhi, vlo
);

always_comb begin
    if (m.valid_hi)
        vhi = m.hi;
    else if (w.valid_hi)
        vhi = w.hi;
    else
        vhi = data_hi;

    if (m.valid_lo)
        vlo = m.lo;
    else if (w.valid_lo)
        vlo = w.lo;
    else
        vlo = data_lo;
end

endmodule
