`include "common.svh"
`include "mycpu/mycpu.svh"

module Fetch (
    input common_context_t CommonContext,
    input fetch_context_t FetchContext,
    
    input decode_stat_t DecodeContextStat, 
    input jmp_pack_t decodeJmp, writeJmp, 
    input logic jmp_delayed,

    output fetch_context_t fetchContext,

    output ibus_req_t  ireq,
    input ibus_resp_t  iresp
);

// only issue fetches when address is aligned on word boundry.
logic addr_invalid;
assign addr_invalid = (|FetchContext.pc[1:0]) || (FetchContext.pc[31:28] < 4'h8) || (FetchContext.pc[31:28] > 4'hb);

assign ireq.valid = !addr_invalid && FetchContext.stat != SF_IDLE;
assign ireq.addr = FetchContext.pc;

i8 interrupts;
logic has_interrupt;

always_comb begin
    fetchContext = FetchContext;
    
    fetchContext.next_pc = FetchContext.pc + 4;
    if (DecodeContextStat) 
        fetchContext.decodeJmp = decodeJmp;
    if (writeJmp.stat != J_NOP)
        fetchContext.writeJmp = writeJmp;
    
    unique case (FetchContext.stat)
        SF_IDLE: begin
            //pass
        end
        SF_FETCH: begin
            if (iresp.addr_ok && iresp.data_ok) begin 
                fetchContext.stat = SF_IDLE;
                fetchContext.instr = iresp.data;
            end
            else if (iresp.addr_ok)
                fetchContext.stat = SF_WAIT;
        end
        SF_WAIT: begin
            if (iresp.data_ok) begin
                fetchContext.stat = SF_IDLE;
                fetchContext.instr = iresp.data;
            end
        end
        default: begin
            // pass
        end
    endcase

    // 更新 delayed_pc_src
    if (jmp_delayed) begin
        fetchContext.exception.delayed = 1;
        fetchContext.exception.delayed_pc_src = decodeJmp.pc_src;
    end

    // 每条指令读取结束后判断是否需要暂停
    //中断源产生中断（包括 ext_int[5:0], cp0.Cause.IP[7:0] 和时钟中断），且对应的中断使能 cp0.Status.IM[7:0] 为有效。时钟中断对应的 mask 为 IM[7]，外部硬件中断对应的 mask 为 IM[7:2]。
    interrupts = CommonContext.cp0.Cause.IP & CommonContext.cp0.Status.IM;

    //cp0.Status.IE 为 1，全局硬件中断使能为有效。?
    has_interrupt = (|interrupts) &&
        CommonContext.cp0.Status.IE &&
        !CommonContext.cp0.Status.ERL &&
        !CommonContext.cp0.Status.EXL;
    
    if (!FetchContext.exception.valid) begin
        if (addr_invalid) begin
            `ADDR_ERROR(fetchContext.exception, EX_ADEL, FetchContext.pc, FetchContext.pc)
            fetchContext.stat = SF_IDLE;
        end
        else if (has_interrupt)
            // NOTE: current instruction has completed, therefore new pc will be recorded in EPC in S_EXCEPTION.
            `THROW(fetchContext.exception, EX_INT, FetchContext.pc);
    end
end

endmodule
