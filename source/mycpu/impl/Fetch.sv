`include "common.svh"
`include "mycpu/mycpu.svh"

module Fetch (
    input logic clk, resetn,
    input cp0_t CommonContext_cp0,
    
    input jmp_pack_t decodeJmp_1_fwd, decodeJmp_2_fwd, writeJmp_fwd,
    
    output decode_context_t fetch2decode_1, fetch2decode_2,

    output flex_bus_req_t  ireq,
    input flex_bus_resp_t  iresp,
    
    input pipeline_stat_t DecodeStat_1, DecodeStat_2, 
    output logic valid_1, valid_2, ready,
    input logic succeed_exception_valid
);
    fetch_stat_t Stat, stat;
    addr_t Pc;
    logic Last_instr_is_jmp;
    
    decode_context_t Fetch_1, Fetch_2, fetch_1, fetch_2;
    jmp_pack_t DecodeJmp_1, DecodeJmp_2, WriteJmp, decodeJmp_1, decodeJmp_2, writeJmp;
    
    always_comb begin
        valid_1 = !writeJmp.en && (!decodeJmp_1.en || Last_instr_is_jmp) && fetch_1.valid;
        valid_2 = !writeJmp.en && !decodeJmp_1.en && !decodeJmp_2.en && fetch_2.valid;
        ready = 1;
        
        if (stat != SF_IDLE)
            {valid_1, valid_2, ready} = '0;
        
        if (DecodeStat_1.ready == 0 || DecodeStat_2.ready == 0)
            ready = 0;
        
        if (succeed_exception_valid)
            {valid_1, valid_2, ready} = '0;
    end
    
    always_comb begin
        if (valid_1) fetch2decode_1 = fetch_1;
        else fetch2decode_1 = '0;
        if (valid_2) fetch2decode_2 = fetch_2;
        else fetch2decode_2 = '0;
    end
    
    logic addr_invalid;
    assign addr_invalid = (|Pc[1:0]) || (Pc[31:28] < 4'h8) || (Pc[31:28] > 4'hb);
    
    assign ireq.valid = !addr_invalid && Stat != SF_IDLE && resetn;
    assign ireq.addr = Pc;
    
    // 每条指令读取结束后判断是否需要暂停
    // 中断源产生中断（包括 ext_int[5:0], cp0.Cause.IP[7:0] 和时钟中断），且对应的中断使能 cp0.Status.IM[7:0] 为有效。时钟中断对应的 mask 为 IM[7]，外部硬件中断对应的 mask 为 IM[7:2]。
    i8 interrupts;
    assign interrupts = CommonContext_cp0.Cause.IP & CommonContext_cp0.Status.IM;
    
    //cp0.Status.IE 为 1，全局硬件中断使能为有效。?
    logic has_interrupt;
    assign has_interrupt = (|interrupts) && CommonContext_cp0.Status.IE && !CommonContext_cp0.Status.ERL && !CommonContext_cp0.Status.EXL;
    
    logic fetch_valid;
    assign fetch_valid = Stat != SF_IDLE && stat == SF_IDLE;
    
    Fetch_single Fetch_single_inst_1(.valid(fetch_valid), .pc(Pc), .instr(iresp.data_1), 
                                     .Last_instr_is_jmp(Last_instr_is_jmp),
                                     .addr_invalid(addr_invalid), .has_interrupt(has_interrupt), 
                                     .Fetch(Fetch_1), .fetch(fetch_1));
    
    Fetch_single Fetch_single_inst_2(.valid(iresp.valid_2 && fetch_valid), .pc(Pc + 4), .instr(iresp.data_2), 
                                     .Last_instr_is_jmp(iresp.valid_2 && fetch_1.jmp.valid),
                                     .addr_invalid(addr_invalid), .has_interrupt(has_interrupt), 
                                     .Fetch(Fetch_2), .fetch(fetch_2));
    
    always_comb begin
        if (decodeJmp_1_fwd.valid) decodeJmp_1 = decodeJmp_1_fwd;
        else decodeJmp_1 = DecodeJmp_1;
        
        if (decodeJmp_2_fwd.valid) decodeJmp_2 = decodeJmp_2_fwd;
        else decodeJmp_2 = DecodeJmp_2;
        
        if (writeJmp_fwd.valid) writeJmp = writeJmp_fwd;
        else writeJmp = WriteJmp;
    end
    
    always_comb begin
        stat = Stat;
        unique case (Stat)
            SF_IDLE: begin end
            SF_FETCH: begin
                if ((iresp.addr_ok && iresp.data_ok) || addr_invalid) stat = SF_IDLE;
                else if (iresp.addr_ok) stat = SF_WAIT;
            end
            SF_WAIT: begin
                if (iresp.data_ok) stat = SF_IDLE;
            end
            default: begin end
        endcase
    end

    always_ff @(posedge clk) begin
        // Fetch
        if(~resetn) begin
            Pc                <= 32'hbfc00000;
            Last_instr_is_jmp <= 0;
            Stat              <= SF_FETCH;
            {Fetch_1, Fetch_2, DecodeJmp_1, DecodeJmp_2, WriteJmp} <= '0;
        end
        else if (ready == 0) begin
            Pc                <= Pc;
            Last_instr_is_jmp <= Last_instr_is_jmp;
            Stat              <= stat;
            Fetch_1           <= fetch_1;
            Fetch_2           <= fetch_2;
            DecodeJmp_1       <= decodeJmp_1;
            DecodeJmp_2       <= decodeJmp_2; 
            WriteJmp          <= writeJmp;
        end
        else begin
            if (writeJmp.en) begin
                Pc                <= writeJmp.pc_dst;
                Last_instr_is_jmp <= 0;
            end
            else if (decodeJmp_1.en) begin
                Pc                <= decodeJmp_1.pc_dst;
                Last_instr_is_jmp <= 0;
            end
            else if (decodeJmp_2.en) begin
                Pc                <= decodeJmp_2.pc_dst;
                Last_instr_is_jmp <= 0;
            end
            else begin 
                Pc                <= Pc + (valid_1 ? 4 : 0) + (valid_2 ? 4 : 0);
                Last_instr_is_jmp <= (fetch_1.jmp.valid && !fetch_2.valid) || fetch_2.jmp.valid;
            end
            Stat <= SF_FETCH;
            {Fetch_1, Fetch_2, DecodeJmp_1, DecodeJmp_2, WriteJmp} <= '0;
        end
    end

endmodule
