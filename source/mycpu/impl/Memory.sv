`include "common.svh"
`include "mycpu/mycpu.svh"

module Memory (
    input common_context_t CommonContext,
    input memory_context_t MemoryContext,
    input write_context_t WriteContext,
    input logic WriteContextExceptionValid, 
    input op_t Write_op,
    output memory_context_t memoryContext,

    output dbus_req_t  dreq,
    input dbus_resp_t  dresp
);

logic valid_0;
logic msize2_addr_error, msize4_addr_error;

assign valid_0 = MemoryContext.memory_args.valid && 
                 MemoryContext.stat != SM_IDLE &&
                 !MemoryContext.exception.valid && 
                 !WriteContextExceptionValid && 
                 Write_op != ERET;

assign msize2_addr_error = valid_0 &&
                           MemoryContext.memory_args.msize == MSIZE2 && 
                           MemoryContext.memory_args.addr[0] == 1'b1;
assign msize4_addr_error = valid_0 && (MemoryContext.op == LW || MemoryContext == SW) &&
                           MemoryContext.memory_args.msize == MSIZE4 && 
                           MemoryContext.memory_args.addr[1:0] != 2'b0;

assign dreq.valid = valid_0 && (!msize2_addr_error) && (!msize4_addr_error);
assign dreq.addr = MemoryContext.memory_args.addr;
assign dreq.size = MemoryContext.memory_args.msize;
Memory_Select_Dreq_Strobe Memory_Select_Dreq_Strobe_Inst(.MemoryArgs(MemoryContext.memory_args), .op(MemoryContext.op), .strobe(dreq.strobe));
Memory_Select_Dreq_Data Memory_Select_Dreq_Data_Inst(.MemoryArgs(MemoryContext.memory_args), .op(MemoryContext.op), .data(dreq.data));

word_t m_data;

Memory_Select_Dresp_Data Memory_Select_Dresp_Data_Inst(
    .MemoryArgs(MemoryContext.memory_args), 
    .op(MemoryContext.op),
    .raw_data(dresp.data),
    .ref_data(MemoryContext.write_reg.dst != 5'b0 && WriteContext.write_reg.valid && WriteContext.write_reg.dst == MemoryContext.write_reg.dst ? WriteContext.write_reg.value : CommonContext.r[MemoryContext.write_reg.dst]),
    .data(m_data)
);

always_comb begin
    memoryContext = MemoryContext;
    
    if (valid_0) begin
        if (msize2_addr_error || msize4_addr_error) begin
            if (MemoryContext.memory_args.write)
                `ADDR_ERROR(memoryContext.exception, EX_ADES, MemoryContext.memory_args.addr, MemoryContext.pc)
            else
                `ADDR_ERROR(memoryContext.exception, EX_ADEL, MemoryContext.memory_args.addr, MemoryContext.pc)
            memoryContext.stat = SM_IDLE;
        end
        else begin
            unique case (MemoryContext.stat)
                SM_STORE: begin
                    if (dresp.addr_ok && dresp.data_ok) begin
                        memoryContext.stat = SM_IDLE;
                        memoryContext.memory_args.valid = 0;
                    end
                    else if (dresp.addr_ok)
                        memoryContext.stat = SM_STOREWAIT;
                end
                SM_STOREWAIT: begin
                    if (dresp.data_ok) begin
                        memoryContext.stat = SM_IDLE;
                        memoryContext.memory_args.valid = 0;
                    end
                end
                SM_LOAD: begin
                    if (dresp.addr_ok && dresp.data_ok) begin
                        memoryContext.stat = SM_IDLE;
                        memoryContext.memory_args.valid = 0;
                        if (MemoryContext.write_reg.src == SRC_MEM)
                            memoryContext.write_reg.value = m_data;
                    end
                    else if (dresp.addr_ok)
                        memoryContext.stat = SM_LOADWAIT;
                end
                SM_LOADWAIT: begin
                    if (dresp.data_ok) begin
                        memoryContext.stat = SM_IDLE;
                        memoryContext.memory_args.valid = 0;
                        if (MemoryContext.write_reg.src == SRC_MEM)
                            memoryContext.write_reg.value = m_data;
                    end
                end
                default: begin
                end
            endcase
        end
    end
    else begin
        memoryContext.stat = SM_IDLE;
        memoryContext.memory_args.valid = 0;
    end
end

endmodule
