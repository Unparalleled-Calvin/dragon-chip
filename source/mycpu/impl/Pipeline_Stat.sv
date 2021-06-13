/*
valid = 1 means this stage can output. 
ready = 1 means this stage can input. 

We call the two consecutive stages are (X -> Y):
if Y.ready = 0 then X.ready = 0.
if Y.ready = 1 && X.valid = 0 means insert a bubble at Y.
however, sometimes Y.ready = 0 && X.valid = 0 won't bubble Y,
so forcely bubble must use resetn = 0.
Because addr_ok and data_ok are detached, so reset a stage won't make an error in instruction/data load.
*/

`include "common.svh"
`include "mycpu/mycpu.svh"

module Pipeline_Stat(
    input resetn, 
    input fetch_context_t fetchContext,
    input decode_context_t decodeContext,
    input execute_context_t executeContext,
    input memory_context_t memoryContext,
    input write_context_t WriteContext,
    output pipeline_stat_t FetchStat, DecodeStat, ExecuteStat, MemoryStat, WriteStat
);

i1 FetchDone, ExecuteDone, MemoryDone;
assign FetchDone = fetchContext.stat == SF_IDLE;
assign ExecuteDone = (executeContext.stat == SE_IDLE);
assign MemoryDone = (memoryContext.stat == SM_IDLE);

logic MTC0_exist;
assign MTC0_exist = (memoryContext.op == MTC0) || (executeContext.op == MTC0) || (decodeContext.op == MTC0);

logic load_use_hazard;
assign load_use_hazard = executeContext.write_reg.valid && 
                         executeContext.write_reg.src == SRC_MEM && 
                         executeContext.write_reg.dst != 5'b0 && 
                         (decodeContext.vars.rs == executeContext.write_reg.dst || 
                         decodeContext.vars.rt == executeContext.write_reg.dst);

always_comb begin
    FetchStat = 3'b111;
    DecodeStat = 3'b111;
    ExecuteStat = 3'b111;
    MemoryStat = 3'b111;
    WriteStat = 3'b111;
    
    if (~resetn) begin
        FetchStat.resetn = 0;
        DecodeStat.resetn = 0;
        ExecuteStat.resetn = 0;
        MemoryStat.resetn = 0;
        WriteStat.resetn = 0;
    end
    
    if (!MemoryDone) begin
        MemoryStat.valid = 0;
        MemoryStat.ready = 0;
    end
    
    if (!ExecuteDone) begin
        ExecuteStat.valid = 0;
        ExecuteStat.ready = 0;
    end
    
    if (!FetchDone) begin
        FetchStat.valid = 0;
        FetchStat.ready = 0;
    end

    if (load_use_hazard) begin
        DecodeStat.valid = 0;
        DecodeStat.ready = 0;
    end

    if (WriteContext.exception.valid || WriteContext.op == ERET) begin
        if (!FetchDone || !ExecuteDone) begin
            WriteStat.ready = 0;
            WriteStat.valid = 0;
            MemoryStat.valid = 0;
            ExecuteStat.valid = 0;
            DecodeStat.valid = 0;
        end
        else begin
            WriteStat.resetn = 0;
            MemoryStat.resetn = 0;
            ExecuteStat.resetn = 0;
            DecodeStat.resetn = 0;
        end
    end
    else if ((memoryContext.op == MTC0) || (executeContext.op == MTC0) || (decodeContext.op == MTC0)) begin
        FetchStat.valid = 0;
        FetchStat.ready = 0;
    end

    if (WriteStat.ready == 0)
        MemoryStat.ready = 0;

    if (MemoryStat.ready == 0)
        ExecuteStat.ready = 0;

    if (ExecuteStat.ready == 0)
        DecodeStat.ready = 0;

    if (DecodeStat.ready == 0)
        FetchStat.ready = 0;
end

endmodule
