`include "common.svh"
`include "mycpu/mycpu.svh"

module Write(
    input logic clk, resetn,
    input common_context_t CommonContext,
    input write_single_context_t memory2write_1, memory2write_2, 
    input i6 ext_int, 
    
    output write_reg_t write_reg_1, write_reg_2, 
    output write_hilo_t write_hilo_1, write_hilo_2, 
    output jmp_pack_t writeJmp_fwd, 
    output common_context_t commonContext,
    output pipeline_stat_t WriteStat,
    output logic exception_valid, ERET_exist, MTC0_exist
);
    write_context_t WriteContext;
    
    always_comb begin
        WriteStat = 2'b11;
        /*
        if (WriteContext.valid2) begin
            WriteStat.valid = 0;
            WriteStat.ready = 0;
        end*/
    end
    
    addr_t w_pc /* verilator public_flat_rd */;
    creg_addr_t w_reg /* verilator public_flat_rd */;
    word_t w_value /* verilator public_flat_rd */;
    i4 w_enable /* verilator public_flat_rd */;
    
    assign write_reg_1 = WriteContext.write_1.write_reg;
    assign write_hilo_1 = WriteContext.write_1.write_hilo;
    assign write_reg_2 = WriteContext.write_2.write_reg;
    assign write_hilo_2 = WriteContext.write_2.write_hilo;
    
    assign exception_valid = WriteContext.write_1.exception.valid || WriteContext.write_2.exception.valid;
    assign ERET_exist = WriteContext.write_1.op == ERET || WriteContext.write_2.op == ERET;
    assign MTC0_exist = WriteContext.write_1.op == MTC0 || WriteContext.write_2.op == MTC0; 
    
    common_context_t commonContext_0, commonContext_1, commonContext_2;
    
    always_comb begin
        commonContext_0 = CommonContext;
        commonContext_0.cp0.Cause.IP[7] = ext_int[5] || CommonContext.cp0.Cause.TI;
        commonContext_0.cp0.Cause.IP[6:2] = ext_int[4:0];

        // 每个周期结束后更新并判断是否需要中断
        // set external interrupts
        // invoke timer interrupt at the next cycle
        if (commonContext_0.cp0.Count + 1 == CommonContext.cp0.Compare)
            // 不涉及这个异常，所以先不管了。
            // 可能会影响到前序指令的执行。
            // 如果要 THROW 一个异常的话，应当放到 Fetch 阶段？
            commonContext_0.cp0.Cause.TI = 1;

        // increment Count
        commonContext_0.cp0.Count = CommonContext.cp0.Count + 1;
    end
    
    
    Write_processing Write_processing_inst_1(.WriteContext(WriteContext.write_1), 
                                             .ext_int(ext_int),
                                             .CommonContext(commonContext_0), 
                                             .commonContext(commonContext_1));
    Write_processing Write_processing_inst_2(.WriteContext(WriteContext.write_2), 
                                             .ext_int(ext_int),
                                             .CommonContext(commonContext_1), 
                                             .commonContext(commonContext_2));
    
    jmp_pack_t writeJmp_1, writeJmp_2;
    Write_Jmp Write_Jmp_inst_1(.WriteContext(WriteContext.write_1), .CommonContext(commonContext), .writeJmp(writeJmp_1));
    Write_Jmp Write_Jmp_inst_2(.WriteContext(WriteContext.write_2), .CommonContext(commonContext), .writeJmp(writeJmp_2));
    
    always_comb begin
        /*
        if (WriteContext.valid2) begin
            commonContext = CommonContext;
            writeJmp_fwd = '0;
            w_pc = WriteContext.write_1.pc;
            w_reg = WriteContext.write_1.write_reg.dst;
            w_value = WriteContext.write_1.write_reg.value;
            w_enable = {4{WriteContext.write_1.write_reg.valid && 
                          WriteContext.write_1.op != MTC0 && 
                          !WriteContext.write_1.exception.valid && 
                          WriteContext.write_1.write_reg.dst != '0}};
        end
        else*/ begin
            if (WriteContext.write_1.exception.valid || WriteContext.write_1.op == ERET)
                commonContext = commonContext_1;
            else
                commonContext = commonContext_2;
            if (writeJmp_1.valid) 
                writeJmp_fwd = writeJmp_1;
            else
                writeJmp_fwd = writeJmp_2;
            w_pc = WriteContext.write_2.pc;
            w_reg = WriteContext.write_2.write_reg.dst;
            w_value = WriteContext.write_2.write_reg.value;
            w_enable = {4{WriteContext.write_2.write_reg.valid && 
                          WriteContext.write_2.op != MTC0 && 
                          !WriteContext.write_2.exception.valid && 
                          WriteContext.write_2.write_reg.dst != '0}};
        end
    end
    
    always_ff @(posedge clk) begin
        // Write
        if(~resetn)
            WriteContext <= WRITE_CONTEXT_RESET;
        /*else if (WriteStat.ready == 0) begin
            WriteContext.valid2 <= 0;
        end*/
        else begin
            WriteContext.valid2 <= memory2write_1.op != NOP;
            WriteContext.write_1 <= memory2write_1;
            WriteContext.write_2 <= memory2write_2;
        end
    end
endmodule
