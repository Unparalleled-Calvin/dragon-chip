`include "common.svh"
`include "mycpu/mycpu.svh"

module Memory_Select_Dreq_Data (
    input memory_args_t MemoryArgs,
    input op_t op,
    output word_t data
);

i2 offset;
assign offset = MemoryArgs.addr[1:0];

always_comb begin
    if (MemoryArgs.valid && MemoryArgs.write) begin
        unique case (MemoryArgs.msize)
            MSIZE1: begin
                unique case (offset)
                    2'b00: data = {{24'h0}, MemoryArgs.data[7:0]};
                    2'b01: data = {{16'h0}, MemoryArgs.data[7:0], {8'h0}};
                    2'b10: data = {{8'h0}, MemoryArgs.data[7:0], {16'h0}};
                    2'b11: data = {MemoryArgs.data[7:0], {24'h0}};
                endcase
            end
            MSIZE2: begin
                unique case (offset)
                    2'b00: data = {{16'h0}, MemoryArgs.data[15:0]};
                    2'b10: data = {MemoryArgs.data[15:0], {16'h0}};
                    default: data = 32'h0;
                endcase
            end
            MSIZE4:  begin
                if (op == SWL) begin
                    unique case(offset)
                        2'b00: data = {24'b0, MemoryArgs.data[31:24]};
                        2'b01: data = {16'b0, MemoryArgs.data[31:16]};
                        2'b10: data = {8'b0, MemoryArgs.data[31:8]};
                        2'b11: data = MemoryArgs.data;
                    endcase
                end else if (op == SWR) begin
                    unique case(offset)
                        2'b00: data = MemoryArgs.data;
                        2'b01: data = {MemoryArgs.data[23:0], 8'b0}
                        2'b10: data = {MemoryArgs.data[15:0], 16'b0};
                        2'b11: data = {MemoryArgs.data[7:0], 24'b0}
                    endcase
                end else
                    unique case (offset)
                        2'b00: data = MemoryArgs.data;
                        default: data = 32'h0;
                    endcase
            end
            default: data = 32'h0;
        endcase
    end
    else
        data = 32'h0;
end

endmodule
