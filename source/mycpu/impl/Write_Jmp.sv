`include "common.svh"
`include "mycpu/mycpu.svh"

module Write_Jmp (
    input write_single_context_t WriteContext, 
    input common_context_t CommonContext,
    output jmp_pack_t writeJmp
);

    always_comb begin
        writeJmp = '0;
        if (WriteContext.exception.valid) begin
            writeJmp.en  = 1;
            writeJmp.pc_dst = 32'hbfc00380;
            writeJmp.valid = 1;
        end
        else if (WriteContext.op == ERET) begin
            if (CommonContext.cp0.Status.ERL) begin
                // 对于 syscall 类型的异常，当异常返回时，应该返回到下一条指令。
                writeJmp.en  = 1;
                writeJmp.pc_dst = CommonContext.cp0.ErrorEPC;
                writeJmp.valid = 1;
            end
            else begin
                // 下一条指令的 PC 置为 cp0.EPC。
                writeJmp.en  = 1;
                writeJmp.pc_dst = CommonContext.cp0.EPC;
                writeJmp.valid = 1;
            end
        end
        else if (WriteContext.op == MTC0) begin
            writeJmp.en  = 1;
            writeJmp.pc_dst = WriteContext.pc + 4;
            writeJmp.valid = 1;
        end
    end

endmodule
