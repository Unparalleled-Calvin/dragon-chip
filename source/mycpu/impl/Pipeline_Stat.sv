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

always_comb begin
    if (~resetn) begin
        FetchStat = NORMAL;
        DecodeStat = NORMAL;
        ExecuteStat = NORMAL;
        MemoryStat = NORMAL;
        WriteStat = NORMAL;
    end
    else if (!MemoryDone) begin
        // d_data_ok = false
        FetchStat = STALL;
        DecodeStat = STALL;
        ExecuteStat = STALL;
        MemoryStat = STALL;
        WriteStat = BUBBLE;
    end
    else if (WriteContext.exception.valid || WriteContext.op == ERET) begin
        if (!FetchDone) begin
            FetchStat = STALL;
            DecodeStat = BUBBLE;
            ExecuteStat = BUBBLE;
            MemoryStat = BUBBLE;
            WriteStat = STALL;
        end
        else begin
            FetchStat = NORMAL;
            DecodeStat = BUBBLE;
            ExecuteStat = BUBBLE;
            MemoryStat = BUBBLE;
            WriteStat = BUBBLE;
        end
    end
    else if (!ExecuteDone) begin
        // e_data_ok = false
        FetchStat = STALL;
        DecodeStat = STALL;
        ExecuteStat = STALL;
        MemoryStat = BUBBLE;
        WriteStat = NORMAL;
    end
    else if (executeContext.write_reg.valid && 
                executeContext.write_reg.src == SRC_MEM && 
                executeContext.write_reg.dst != 5'b0 && 
                (decodeContext.vars.rs == executeContext.write_reg.dst || 
                 decodeContext.vars.rt == executeContext.write_reg.dst)
            ) begin
        // E read memory write reg & D read reg
        FetchStat = STALL;
        DecodeStat = STALL;
        ExecuteStat = BUBBLE;
        MemoryStat = NORMAL;
        WriteStat = NORMAL;
    end
    else if (!FetchDone) begin
        // i_data_ok = false
        FetchStat = STALL;
        DecodeStat = STALL;
        ExecuteStat = BUBBLE;
        MemoryStat = NORMAL;
        WriteStat = NORMAL;
    end
    else if (MTC0_exist) begin
        FetchStat = STALL;
        DecodeStat = BUBBLE;
        ExecuteStat = NORMAL;
        MemoryStat = NORMAL;
        WriteStat = NORMAL;
    end
    else begin
        FetchStat = NORMAL;
        DecodeStat = NORMAL;
        ExecuteStat = NORMAL;
        MemoryStat = NORMAL;
        WriteStat = NORMAL;
    end 
end

endmodule
