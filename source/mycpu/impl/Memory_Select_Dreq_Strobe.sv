`include "common.svh"
`include "mycpu/mycpu.svh"

module Memory_Select_Dreq_Strobe (
    input memory_args_t MemoryArgs,

    output i4 strobe
);

i2 offset;
assign offset = MemoryArgs.addr[1:0];

always_comb begin
    if (MemoryArgs.valid && MemoryArgs.write) begin
        unique case (MemoryArgs.msize)
            MSIZE1: begin
                unique case (offset)
                    2'b00: strobe = 4'b0001;
                    2'b01: strobe = 4'b0010;
                    2'b10: strobe = 4'b0100;
                    2'b11: strobe = 4'b1000;
                endcase
            end
            MSIZE2: begin
                unique case (offset)
                    2'b00: strobe = 4'b0011;
                    2'b10: strobe = 4'b1100;
                    default: strobe = 4'b0000;
                endcase
            end
            MSIZE4: begin
                unique case (offset)
                    2'b00: strobe = 4'b1111;
                    default: strobe = 4'b0000;
                endcase
            end
            default: strobe = 4'b0000;
        endcase
    end else
        strobe = 4'b0000;
end

endmodule
