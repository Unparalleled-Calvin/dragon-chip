`include "common.svh"
`include "mycpu/mycpu.svh"

module Memory_single (
    input logic clk, resetn,
    input memory_context_t execute2memory,
    input logic exception_valid_1,
    output dbus_req_t  dreq,
    input dbus_resp_t  dresp,
    output write_single_context_t memory2write,
    
    output write_reg_t write_reg,
    output write_hilo_t write_hilo,
    input pipeline_stat_t MemoryStat,
    input logic succeed_exception_valid,
    
    output logic exception_valid, ERET_exist, MTC0_exist,
    output logic done, done_doned, error
);

    memory_stat_t Stat, stat;
    word_t Pc;
    op_t Op;
    memory_args_t Memory_args, memory_args;
    write_reg_t Write_reg;
    write_hilo_t Write_hilo;
    logic Drop, drop;
    exception_args_t Exception, exception;
    
    assign exception_valid = exception.valid;
    assign ERET_exist = Op == ERET;
    assign MTC0_exist = Op == MTC0;
    
    assign write_hilo = Write_hilo;
    assign done = stat == SM_IDLE;
    assign done_doned = Stat == SM_IDLE;
    assign error = Exception.valid || Op == ERET || Op == MTC0;
    
    logic valid_0;
    logic msize2_addr_error, msize4_addr_error;

    assign valid_0 = Memory_args.valid && 
                     Stat != SM_IDLE &&
                     !Exception.valid && 
                     !succeed_exception_valid;

    assign msize2_addr_error = valid_0 &&
                           Memory_args.msize == MSIZE2 && 
                           Memory_args.addr[0] == 1'b1;
    assign msize4_addr_error = valid_0 &&
                           Memory_args.msize == MSIZE4 && 
                           Memory_args.addr[1:0] != 2'b0;

    assign dreq.valid = valid_0 && (!msize2_addr_error) && (!msize4_addr_error) && (!exception_valid_1);
    assign dreq.addr = Memory_args.addr;
    assign dreq.size = Memory_args.msize;
    Memory_Select_Dreq_Strobe Memory_Select_Dreq_Strobe_Inst(.MemoryArgs(Memory_args), .strobe(dreq.strobe));
    Memory_Select_Dreq_Data Memory_Select_Dreq_Data_Inst(.MemoryArgs(Memory_args), .data(dreq.data));

    word_t m_data;

    Memory_Select_Dresp_Data Memory_Select_Dresp_Data_Inst(
        .MemoryArgs(Memory_args), 
        .raw_data(dresp.data),
        .data(m_data)
    );

    always_comb begin
        if (succeed_exception_valid)
            drop = 1;
        else
            drop = Drop;
    end
    
    always_comb begin
        stat = Stat;
        memory_args = Memory_args;
        write_reg = Write_reg;
        
        if (valid_0) begin
            if (msize2_addr_error || msize4_addr_error) begin
                stat = SM_IDLE;
                memory_args.valid = 0;
            end
            else begin
                unique case (Stat)
                    SM_STORE: begin
                        if (dresp.addr_ok) begin
                            stat = SM_IDLE;
                            memory_args.valid = 0;
                        end
                    end
                    SM_LOAD: begin
                        if (dresp.addr_ok && dresp.data_ok) begin
                            stat = SM_IDLE;
                            memory_args.valid = 0;
                            if (Write_reg.src == SRC_MEM)
                                write_reg.value = m_data;
                        end
                        else if (dresp.addr_ok)
                            stat = SM_LOADWAIT;
                    end
                    SM_LOADWAIT: begin
                        if (dresp.data_ok) begin
                            stat = SM_IDLE;
                            memory_args.valid = 0;
                            if (Write_reg.src == SRC_MEM)
                                write_reg.value = m_data;
                        end
                    end
                    default: begin
                    end
                endcase
            end
        end
        else begin
            stat = SM_IDLE;
            memory_args.valid = 0;
        end
    end

    always_comb begin
        exception = Exception;
        
        if (valid_0 && (msize2_addr_error || msize4_addr_error)) begin
            if (Memory_args.write)
                `ADDR_ERROR(exception, EX_ADES, Memory_args.addr, Pc)
            else
                `ADDR_ERROR(exception, EX_ADEL, Memory_args.addr, Pc)
        end
    end

    always_comb begin
        memory2write = WRITE_SINGLE_CONTEXT_RESET;
        if (MemoryStat.valid == 1 && drop == 0) begin
            memory2write.pc = Pc;
            memory2write.op = Op;
            memory2write.write_reg = write_reg;
            memory2write.write_hilo = Write_hilo;
            memory2write.exception = exception;
        end
    end

    always_ff @(posedge clk) begin
        // Memory
        if(~resetn)
            {Stat, Pc, Op, Memory_args, Write_reg, Write_hilo, Drop, Exception}
             <= MEMORY_CONTEXT_RESET;
        else if (MemoryStat.ready == 0)
            {Stat, Pc, Op, Memory_args, Write_reg, Write_hilo, Drop, Exception}
             <= {stat, Pc, Op, memory_args, write_reg, Write_hilo, drop, exception};
        else
            {Stat, Pc, Op, Memory_args, Write_reg, Write_hilo, Drop, Exception}
             <= execute2memory;
    end

endmodule
