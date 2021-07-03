`include "common.svh"
`include "mycpu/mycpu.svh"

module Fetch_Memory_args (
    input op_t op,
    output memory_args_t memory_args
);

    always_comb begin
        memory_args = '0;
        unique case (op)
            SB: begin
                memory_args.valid = 1;
                memory_args.write = 1;
                memory_args.sig = SIGNED;
                memory_args.msize = MSIZE1;
                memory_args.data = 32'h0;
            end
            SH: begin
                memory_args.valid = 1;
                memory_args.write = 1;
                memory_args.sig = SIGNED;
                memory_args.msize = MSIZE2;
                memory_args.data = 32'h0;
            end
            SW: begin
                memory_args.valid = 1;
                memory_args.write = 1;
                memory_args.sig = SIGNED;
                memory_args.msize = MSIZE4;
                memory_args.data = 32'h0;
            end
            LB: begin
                memory_args.valid = 1;
                memory_args.write = 0;
                memory_args.sig = SIGNED;
                memory_args.msize = MSIZE1;
                memory_args.data = 32'b0;
               end
            LBU: begin
                memory_args.valid = 1;
                memory_args.write = 0;
                memory_args.sig = UNSIGNED;
                memory_args.msize = MSIZE1;
                memory_args.data = 32'b0;
            end
            LH: begin
                memory_args.valid = 1;
                memory_args.write = 0;
                memory_args.sig = SIGNED;
                memory_args.msize = MSIZE2;
                memory_args.data = 32'b0;
            end
            LHU: begin
                memory_args.valid = 1;
                memory_args.write = 0;
                memory_args.sig = UNSIGNED;
                memory_args.msize = MSIZE2;
                memory_args.data = 32'b0;
            end
            LW: begin
                memory_args.valid = 1;
                memory_args.write = 0;
                memory_args.sig = SIGNED;
                memory_args.msize = MSIZE4;
                memory_args.data = 32'b0;
            end
            default: begin
                memory_args = '0;
            end
        endcase
    end

endmodule
