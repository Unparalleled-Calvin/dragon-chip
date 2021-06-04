`include "common.svh"
`include "mycpu/mycpu.svh"

module Write (
    input common_context_t CommonContext,
    input write_context_t WriteContext,
    input i6 ext_int, 
    
    output jmp_pack_t writeJmp, 
    output common_context_t commonContext
);
    addr_t w_pc /* verilator public_flat_rd */;
    creg_addr_t w_reg /* verilator public_flat_rd */;
    word_t w_value /* verilator public_flat_rd */;
    i4 w_enable /* verilator public_flat_rd */;
    
    assign w_pc = WriteContext.pc;
    assign w_reg = WriteContext.write_reg.dst;
    assign w_value = WriteContext.write_reg.value;
    assign w_enable = {4{WriteContext.write_reg.valid && WriteContext.op != MTC0 && !WriteContext.exception.valid && WriteContext.write_reg.dst != '0}};

    always_comb begin
        commonContext = CommonContext;
        commonContext.cp0.Cause.IP[7] = ext_int[5] || CommonContext.cp0.Cause.TI;
        commonContext.cp0.Cause.IP[6:2] = ext_int[4:0];

        // 每个周期结束后更新并判断是否需要中断
        // set external interrupts
        // invoke timer interrupt at the next cycle
        if (commonContext.cp0.Count + 1 == CommonContext.cp0.Compare)
            // 不涉及这个异常，所以先不管了。
            // 可能会影响到前序指令的执行。
            // 如果要 THROW 一个异常的话，应当放到 Fetch 阶段？
            commonContext.cp0.Cause.TI = 1;

        // increment Count
        commonContext.cp0.Count = CommonContext.cp0.Count + 1;

        // 只对W阶段的异常改变状态，其他阶段的异常需要先到达W阶段
        if (WriteContext.exception.valid) begin
            //if (CommonContext.cp0.Status.ERL) `FATAL //如果 ERL=1 则进入未定义状态

            // fill CP0 registers
            // 如果 cp0.Status.EXL 为 0，设置 cp0.EPC 和 cp0.Cause.BD。
            // 如果产生异常的指令不在分支延迟槽中，将 cp0.EPC 设为该指令的 PC，并将 cp0.Cause.BD 设为 0；
            // 否则，将 cp0.EPC 设置为分支/跳转指令的 PC（即当前 PC 减 4），并将 cp0.Cause.BD 设为 1。
            if (!CommonContext.cp0.Status.EXL) begin
                if (WriteContext.exception.delayed) begin
                    commonContext.cp0.Cause.BD = 1;
                    commonContext.cp0.EPC = WriteContext.exception.pc_src - 4;
                end
                else begin
                    commonContext.cp0.Cause.BD = 0;
                    commonContext.cp0.EPC = WriteContext.exception.pc_src;
                end
            end

            // 将 cp0.Status.EXL 设置为 1。
            commonContext.cp0.Status.EXL = 1;
            // 如果是地址错异常，将出错的虚拟地址写入 cp0.BadVAddr
            commonContext.cp0.BadVAddr = WriteContext.exception.bad_vaddr;
            // 本实验需要实现的 code 包括：Int、AdEL、AdES、Sys、BP、RI、Ov。
            commonContext.cp0.Cause.ExcCode = WriteContext.exception.code;

            // evaluate exception vector
            // 中断来源是 Interrupt
            /*
            if (args.code == EX_INT) begin
                // cp0.Status.EXL 为 0，CPU 在执行异常处理程序时，不允许中断。
                if (CommonContext.cp0.Status.EXL || CommonContext.cp0.Status.ERL)
                    `FATAL
                unique case ({ctx.cp0.r.Status.BEV, ctx.cp0.r.Cause.IV})
                    2'b00: out.pc = 32'h80000180;
                    2'b01: out.pc = 32'h80000200;
                    2'b10: out.pc = 32'hbfc00380;
                    2'b11: out.pc = 32'hbfc00400;
                endcase
            end
            else begin
                out.pc = ctx.cp0.r.Status.BEV ? 32'hbfc00380 : 32'h80000180;
            end*/
        end
        else if (WriteContext.op == ERET) begin
            if (CommonContext.cp0.Status.ERL)
                // 对于 syscall 类型的异常，当异常返回时，应该返回到下一条指令。
                commonContext.cp0.Status.ERL = 0;
            else
                // cp0.Status.EXL ← 0。
                commonContext.cp0.Status.EXL = 0;

            // if (CommonContext.delayed) `FATAL
        end
        else begin
            if (WriteContext.write_reg.valid) begin
                if (WriteContext.op == MTC0) begin
                    unique case (WriteContext.write_reg.dst)
                        5'd8:  commonContext.cp0.BadVAddr = WriteContext.write_reg.value;
                        5'd9:  commonContext.cp0.Count = WriteContext.write_reg.value;
                        5'd11: begin
                            commonContext.cp0.Compare = WriteContext.write_reg.value;
                            commonContext.cp0.Cause.TI = 0;  // clears timer interrupt
                        end
                        5'd12: commonContext.cp0.Status = WriteContext.write_reg.value;
                        5'd13: commonContext.cp0.Cause = WriteContext.write_reg.value;
                        5'd14: commonContext.cp0.EPC = WriteContext.write_reg.value;
                        5'd30: commonContext.cp0.ErrorEPC = WriteContext.write_reg.value;
                        default: begin end // TODO ERROR
                    endcase
                end
                else if (WriteContext.write_reg.dst != 0)
                    commonContext.r[WriteContext.write_reg.dst] = WriteContext.write_reg.value;
            end
            
            if (WriteContext.write_hilo.valid_hi)
                commonContext.hi = WriteContext.write_hilo.hi;
            
            if (WriteContext.write_hilo.valid_lo)
                commonContext.lo = WriteContext.write_hilo.lo;
        end
    end

always_comb begin
    writeJmp = '0;
    if (WriteContext.exception.valid) begin
        writeJmp.stat = J_DIR;
        writeJmp.pc_dst = 32'hbfc00380;
        writeJmp.pc_src = WriteContext.pc;
    end
    else if (WriteContext.op == ERET) begin
        if (CommonContext.cp0.Status.ERL) begin
            // 对于 syscall 类型的异常，当异常返回时，应该返回到下一条指令。
            writeJmp.stat = J_DIR;
            writeJmp.pc_dst = CommonContext.cp0.ErrorEPC;
            writeJmp.pc_src = WriteContext.pc;
        end
        else begin
            // 下一条指令的 PC 置为 cp0.EPC。
            writeJmp.stat = J_DIR;
            writeJmp.pc_dst = CommonContext.cp0.EPC;
            writeJmp.pc_src = WriteContext.pc;
        end
    end
end


endmodule
