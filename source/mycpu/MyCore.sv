`include "common.svh"
`include "mycpu/mycpu.svh"

module MyCore (
    input logic clk, resetn,
    output ibus_req_t  ireq,
    input  ibus_resp_t iresp,
    output dbus_req_t  dreq,
    input  dbus_resp_t dresp,
    input i6 ext_int
);

common_context_t CommonContext, commonContext;

fetch_context_t FetchContext, fetchContext, fetchContext_NORMAL;

decode_context_t DecodeContext, decodeContext, decodeContext_NORMAL;

execute_context_t ExecuteContext, executeContext, executeContext_NORMAL;

memory_context_t MemoryContext, memoryContext, memoryContext_NORMAL;

write_context_t WriteContext, writeContext_NORMAL;

jmp_pack_t decodeJmp, writeJmp;

logic jmp_delayed;

Fetch Fetch_inst(.DecodeContextStat(DecodeContext.stat), .*);

Decode Decode_inst(.*);

Execute Execute_inst(.*);

Memory Memory_inst(.WriteContextExceptionValid(WriteContext.exception.valid), .Write_op(WriteContext.op), .*);

Write Write_inst(.*);

pipeline_stat_t FetchStat, DecodeStat, ExecuteStat, MemoryStat, WriteStat;

Pipeline_Stat Pipeline_Stat_Inst(.*);

// Bubble Stall 由 pipelinestat_t 单独控制，
// 流水线寄存器在 PipelineStat 中统一更新。
// 可以加一个状态机转移结果数组，可以对所有值进行赋值。

always_comb begin
    fetchContext_NORMAL = FETCH_CONTEXT_RESET;
    fetchContext_NORMAL.stat = SF_FETCH;
    if (fetchContext.writeJmp.stat != J_NOP)
        fetchContext_NORMAL.pc = fetchContext.writeJmp.pc_dst;
    else if (fetchContext.decodeJmp.stat != J_NOP)
        fetchContext_NORMAL.pc = fetchContext.decodeJmp.pc_dst;
    else
        fetchContext_NORMAL.pc = fetchContext.next_pc;
    fetchContext_NORMAL.next_pc = fetchContext.next_pc + 4;

    decodeContext_NORMAL = DECODE_CONTEXT_RESET;
    decodeContext_NORMAL.stat = SD_DECODE;
    decodeContext_NORMAL.pc = fetchContext.pc;
    decodeContext_NORMAL.instr = fetchContext.instr;
    decodeContext_NORMAL.exception = fetchContext.exception;

    executeContext_NORMAL = EXECUTE_CONTEXT_RESET;
    if (decodeContext.op == MULT || decodeContext.op == MULTU)
        executeContext_NORMAL.stat = SE_MULT;
    else if (decodeContext.op == DIV || decodeContext.op == DIVU)
        executeContext_NORMAL.stat = SE_DIV;
    else
        executeContext_NORMAL.stat = SE_ALU;
    executeContext_NORMAL.pc = decodeContext.pc;
    executeContext_NORMAL.op = decodeContext.op;
    executeContext_NORMAL.vars = decodeContext.vars;
    executeContext_NORMAL.memory_args = decodeContext.memory_args;
    executeContext_NORMAL.write_reg = decodeContext.write_reg;
    executeContext_NORMAL.write_hilo = decodeContext.write_hilo;
    executeContext_NORMAL.exception = decodeContext.exception;

    memoryContext_NORMAL = MEMORY_CONTEXT_RESET;
    memoryContext_NORMAL.pc = executeContext.pc;
    memoryContext_NORMAL.op = executeContext.op;
    if (executeContext.memory_args.valid == 1 && executeContext.memory_args.write == 0)
        memoryContext_NORMAL.stat = SM_LOAD;
    else if (executeContext.memory_args.valid == 1 && executeContext.memory_args.write == 1)
        memoryContext_NORMAL.stat = SM_STORE;
    else
        memoryContext_NORMAL.stat = SM_IDLE;
    memoryContext_NORMAL.memory_args = executeContext.memory_args;
    memoryContext_NORMAL.write_reg = executeContext.write_reg;
    memoryContext_NORMAL.write_hilo = executeContext.write_hilo;
    memoryContext_NORMAL.exception = executeContext.exception;

    writeContext_NORMAL = WRITE_CONTEXT_RESET;
    writeContext_NORMAL.pc = memoryContext.pc;
    writeContext_NORMAL.op = memoryContext.op;
    writeContext_NORMAL.write_reg = memoryContext.write_reg;
    writeContext_NORMAL.write_hilo = memoryContext.write_hilo;
    writeContext_NORMAL.exception = memoryContext.exception;
end

always_ff @(posedge clk) begin
    // Common
    if(~resetn) begin
        CommonContext <= COMMON_CONTEXT_RESET;
    end
    else
        CommonContext <= commonContext;
    
    // Fetch
    if(~resetn || FetchStat == BUBBLE)
        FetchContext <= FETCH_CONTEXT_RESET;
    else if (FetchStat == STALL)
        FetchContext <= fetchContext;
    else
        FetchContext <= fetchContext_NORMAL;

    // Decode
    if(~resetn || DecodeStat == BUBBLE)
        DecodeContext <= DECODE_CONTEXT_RESET;
    else if (DecodeStat == STALL)
        DecodeContext <= decodeContext;
    else
        DecodeContext <= decodeContext_NORMAL;
    
    // Execute
    if(~resetn || ExecuteStat == BUBBLE)
        ExecuteContext <= EXECUTE_CONTEXT_RESET;
    else if (ExecuteStat == STALL)
        ExecuteContext <= executeContext;
    else
        ExecuteContext <= executeContext_NORMAL;

    // Memory
    if(~resetn || MemoryStat == BUBBLE)
        MemoryContext <= MEMORY_CONTEXT_RESET;
    else if (MemoryStat == STALL)
        MemoryContext <= memoryContext;
    else
        MemoryContext <= memoryContext_NORMAL;

    // Write
    if(~resetn || WriteStat == BUBBLE)
        WriteContext <= WRITE_CONTEXT_RESET;
    else if (WriteStat == STALL) begin
        //pass
    end
    else
        WriteContext <= writeContext_NORMAL;
end

endmodule
